
# TODO: filtrera ut reach utanför 5km

d3 = require './vendor/d3'
async = require './vendor/async'
topojson = require './vendor/topojson'

loadReach = (callback) -> d3.json '/data/reach.json', (error, result) -> callback error, result
loadMap = (callback) -> d3.json '/data/world.topo.json', (error, result) -> callback error, result
domready = (callback) -> window.addEventListener 'DOMContentLoaded', (-> callback()), false

async.parallel
  reach: loadReach
  map: loadMap
  _ready: domready
, (error, result) ->
  throw error if error?
  {reach, map} = result
  main reach, map

nodeColors = d3.scale.ordinal()
  .range(['#00fffd', '#ffcf00', '#ff00ce'])

main = (reachData, mapData) ->
  reachData.forEach (d) ->
    d.nodes = d.nodes.map (n) -> n.data

  # TODO: adapt to window
  width = 960
  height = 500

  svg = d3.select('svg')
    .attr('width', width)
    .attr('height', height)

  projection = d3.geo.mercator()
    .center([35, 63])
    .scale(1500)
    .rotate([20, 0])

  path = d3.geo.path()
    .projection(projection)

  img = d3.select('body').append('img')

  g = svg.append("g")

  map = topojson.feature(mapData, mapData.objects.countries).features

  g.selectAll('path').data(map).enter().append('path')
    .attr('d', path)
    .attr('class', (d) -> "country id#{ d.id }")

  nodePosition = (d) ->
    projection [d.location.longitude, d.location.latitude]

  poiSize = (d) ->
    r = 1 + d.nodes.length
    return [r * 4, r * 4]

  poiPosition = (d) ->
    pos = nodePosition(d)
    size = poiSize(d)
    pos[0] -= size[0] / 2
    pos[1] -= size[1] / 2
    return pos

  posTrans = (pos) ->
    "translate(#{ pos[0] }, #{ pos[1]})"

  pack = d3.layout.pack()
    .padding(2)
    .value((d) -> d.reach.length + 1)
    #.children((d) -> d.nodes)

  pois = g.selectAll('.poi').data(reachData).enter().append('g')
    .attr('class', 'poi')
    .attr('transform', (d) -> posTrans(poiPosition(d)))

  pois.each (d) ->
    poi = d3.select this

    ppos = poiPosition(d)

    pack.size(poiSize(d))

    nodes = pack.nodes({children: d.nodes}).filter (d) ->
      d.depth > 0

    ng = poi.selectAll('.node').data(nodes).enter().append('g')
      .attr('class', 'node')
      .on('click', (d) ->
        img.attr('src', d.images.standard_resolution.url)
      )

    rg = ng.selectAll('.reach').data((d) -> d.reach).enter().append('g')
      .attr('class', 'reach')
      .style('pointer-events', 'none')

    ng.append('circle')
      .attr('cx', (d) -> d.x)
      .attr('cy', (d) -> d.y)
      .attr('r', (d) -> d.r)
      .style('fill', (d, i) -> nodeColors(i))
      .on('mouseover', ->

        n = d3.select this.parentNode
        n.classed('active', true)
      )
      .on('mouseout', ->
        n = d3.select this.parentNode
        n.classed('active', false)
      )

    rg.each (d) ->
      return unless d.location.longitude?
      r = d3.select this
      n = d3.select this.parentNode

      dd = n.datum()
      p = nodePosition(d)
      p[0] -= ppos[0]
      p[1] -= ppos[1]

      r.append('line')
        .attr('x1', dd.x)
        .attr('y1', dd.y)
        .attr('x2', p[0])
        .attr('y2', p[1])

      r.append('circle')
        .attr('r', 2)
        .attr('transform', posTrans(p))

  zoom = d3.behavior.zoom()
    .on('zoom', ->
      g.attr("transform","translate("+d3.event.translate.join(",")+")scale("+d3.event.scale+")")
      g.selectAll("path").attr("d", path.projection(projection))
    )

  svg.call(zoom)
