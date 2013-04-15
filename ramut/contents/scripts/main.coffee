
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

  g = svg.append("g")

  map = topojson.feature(mapData, mapData.objects.countries).features

  g.selectAll('path').data(map).enter().append('path')
    .attr('d', path)
    .attr('class', (d) -> "country id#{ d.id }")

  nodePosition = (d) ->
    projection [d.location.longitude, d.location.latitude]

  nodeTranslation = (d) ->
    pos = nodePosition(d)
    "translate(#{ pos[0] }, #{ pos[1]})"

  reachData = reachData.map (d) -> d.data

  nodes = g.selectAll('.node').data(reachData).enter().append('g')
    .attr('class', 'node')
    .on('click', (d) ->
      console.log d
    )

  nodes.append('circle')
    .attr('r', (d) -> d.reach.length)
    .attr('transform', nodeTranslation)
    .style('fill', (d, i) -> nodeColors(i))

  reach = nodes.selectAll('.reach').data((d) -> d.reach).enter().append('g')
    .attr('class', 'reach')

  reach.each (d) ->
    return unless d.location.longitude?

    node = d3.select this
    parent = d3.select this.parentNode

    pos = nodePosition d
    ppos = nodePosition parent.datum()

    node.append('line')
      .attr('x1', pos[0])
      .attr('y1', pos[1])
      .attr('x2', ppos[0])
      .attr('y2', ppos[1])

    node.append('circle')
      .attr('r', 2)
      .attr('transform', nodeTranslation)

  zoom = d3.behavior.zoom()
    .on('zoom', ->
      g.attr("transform","translate("+d3.event.translate.join(",")+")scale("+d3.event.scale+")")
      g.selectAll("path").attr("d", path.projection(projection))
    )

  svg.call(zoom)
