### storiesofswedishlapland
    instagram reach visualization ###

# filter out reach points that are closer than this
minDistance = 30 # in km
introDuration = 6000
startZoom = 2900
centerPoint = [19.204102, 65.946472] # lng, lat
dotOpacity = 0.75

# feature detects
require 'browsernizr/test/canvas'
require 'browsernizr/test/svg/inline'
browser = require 'browsernizr'

ready = require './vendor/ready'
d3 = require './vendor/d3'
async = require './vendor/async'
topojson = require './vendor/topojson'

rad2deg = (rad) -> rad * 57.295779513
deg2rad = (deg) -> deg * 0.017453293

loadReach = (callback) -> d3.json '/data/reach.json', (error, result) -> callback error, result
loadMap = (callback) -> d3.json '/data/world.topo.json', (error, result) -> callback error, result

clone = (selection) ->
  node = selection.node()
  return d3.select(node.parentNode.insertBefore(node.cloneNode(true), node.nextSibling))

async.parallel
  reach: loadReach
  map: loadMap
  ready: (callback) ->
    ready ->
      if browser.canvas and browser.inlinesvg
        d3.select('body').attr('class', 'loading')
        setTimeout callback, 2000
        #callback()
      else
        callback new Error 'Unsupported browser'
, (error, result) ->
  throw error if error?
  {reach, map} = preprocess result
  d3.select('body').attr('class', 'loaded')
  main reach, map

nodeColors = d3.scale.ordinal()
  .range(['#00fffd', '#ffcf00', '#ff00ce'])

preprocess = (data) ->
  data.reach.forEach (d) ->
    d.nodes.forEach (n) ->
      n.reach = n.reach.filter (r) ->
        gd = d3.geo.distance(
          [r.location.longitude, r.location.latitude]
          [n.location.longitude, n.location.latitude]
        ) * 6371
        return gd > minDistance
    d.nodes = d.nodes.filter (n) ->
      n.reach.length > 0
  return data

main = (reachData, mapData) ->
  globe = {type: 'Sphere'}
  land = topojson.feature(mapData, mapData.objects.land)
  borders = topojson.mesh(mapData, mapData.objects.countries)
  graticule = d3.geo.graticule()()

  width = window.innerWidth
  height = window.innerHeight
  centerOffset = [width/2, height/2]
  centerPoint = [-centerPoint[0], -centerPoint[1]]
  window.addEventListener 'resize', ->
    width = window.innerWidth
    height = window.innerHeight
    centerOffset = [width/2, height/2]
    canvas.attr('width', width).attr('height', height)
    svg.attr('width', width).attr('height', height)
    renderMap()
    updateDots()
  , false

  currentZoom = startZoom
  window.addEventListener 'mousewheel', (event) ->
    return unless event.wheelDelta?
    from = projection.scale()
    mod = Math.log (1 + (from / 100))
    to = from + event.wheelDelta * mod
    to = 300 if to < 300
    to = 15000 if to > 15000
    currentZoom = to
    d3.transition()
      .duration(100)
      .tween('zoom', ->
        f = d3.interpolate from, to
        return (t) ->
          projection.scale f(t)
          renderMap()
          updateDots()
      )
  , false

  canvas = d3.select('body').append('canvas')
    .attr('width', width)
    .attr('height', height)

  ctx = canvas.node().getContext('2d')

  svg = d3.select('body').append('svg')
    .attr('width', width)
    .attr('height', height)

  projection = d3.geo.orthographic()
    .translate(centerOffset)
    .scale(1)
    .rotate([10, -10])
    .clipAngle(90)

  path = d3.geo.path()
    .projection(projection)
    .context(ctx)

  inDetail = false

  goTo = (scale, rotation, offset, duration, callback) ->
    d3.transition()
      .duration(duration)
      .ease('sin-in-out')
      .tween('zoom', ->
        sf = d3.interpolate projection.scale(), scale
        rf = d3.interpolate projection.rotate(), rotation
        tf = d3.interpolate projection.translate(), offset
        return (t) ->
          projection.scale sf t
          projection.rotate rf t
          projection.translate tf t
          renderMap()
          updateDots()
      )
      .each('end', callback)
    return

  renderMap = ->
    ctx.clearRect(0, 0, width, height)

    ctx.fillStyle = '#f1ffff'
    ctx.beginPath()
    path(globe)
    ctx.fill()

    ctx.fillStyle = '#f9f7e9'
    ctx.beginPath()
    path(land)
    ctx.fill()

    ctx.strokeStyle = '#bbb9ad'
    ctx.beginPath()
    path(borders)
    ctx.stroke()

    ctx.globalAlpha = 0.2
    ctx.beginPath()
    path(graticule)
    ctx.stroke()

    ctx.globalAlpha = 1
    ctx.beginPath()
    path(globe)
    ctx.stroke()

    return

  goTo startZoom, centerPoint, centerOffset, introDuration
  setTimeout ->
    svg.selectAll('.node').each (d, i) ->
      d3.select(this).transition().duration(600)
        .delay(i * 20)
        .style('opacity', dotOpacity)
  , introDuration * 0.7

  reachGroup = svg.append('g').classed('reachGroup', true)
  nodeGroup = svg.append('g').classed('nodeGroup', true)

  overlay = d3.select('body').append('div')
    .classed('overlay', true)
    .style('opacity', 0)
    .style('display', 'none')
    .html """
      <div class="inner">
        <a href="#close">X</a>
        <img>
      </div>
    """

  overlay.select('a').on 'click', ->
    d3.event.stopPropagation()
    d3.event.preventDefault()
    hideDetail()

  showOverlay = (data) ->
    overlay.datum data
    overlay.style('display', 'block')
    overlay.select('img').attr('src', (d) ->
      d.images.standard_resolution.url)
    overlay.transition()
      .style('opacity', 1)

  hideOverlay = ->
    overlay.transition().style('opacity', 0).each 'end', ->
      overlay.style('display', 'none')

  nodePosition = (d) ->
    projection [d.location.longitude, d.location.latitude]

  reachExtent = d3.extent reachData, (d) -> d.totalReach
  reachGroupSize = d3.scale.linear()
    .domain(reachExtent)
    .range([8, 80])

  poiSize = (d) ->
    r = reachGroupSize d.totalReach
    return [r, r]

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
    .value((d) -> (d.reach?.length + 1) or 0)

  pois = nodeGroup.selectAll('.poi').data(reachData).enter().append('g')
    .attr('class', 'poi')

  updateDots = ->
    pois.attr('transform', (d) -> posTrans(poiPosition(d)))
    if inDetail
      startPos = null
      svg.selectAll('.activeNode').attr('transform', (d) ->
        startPos = [d.location.longitude, d.location.latitude]
        posTrans(nodePosition(d)))
      svg.selectAll('.reach').each (d) ->
        n = d3.select this
        l = n.select('line')
        p = projection [d.location.longitude, d.location.latitude]
        p2 = projection startPos
        l.attr 'x2', p2[0] - p[0]
        l.attr 'y2', p2[1] - p[1]
        n.attr 'transform', posTrans(p)

  hideDetail = ->
    inDetail = false
    svg.selectAll('.reach').data([]).exit().remove()
    svg.selectAll('.activeNode').data([]).exit().remove()
    goTo currentZoom, centerPoint, centerOffset, 2000
    svg.selectAll('.node').transition().duration(1000).delay(200).style('opacity', dotOpacity)
    hideOverlay()

  showDetail = (d) ->
    inDetail = false
    node = d3.select this
    node.style('opacity', 0)

    opos = node.node().getBoundingClientRect()
    opos = projection.invert [opos.left + (opos.width/2), opos.top + (opos.height/2)]
    startPos = [d.location.longitude, d.location.latitude]

    nodes = d3.selectAll('.node').filter (nd) -> (nd isnt d)
    nodes.transition().duration(400)
      .style('opacity', 0)

    points =
      type: 'MultiPoint'
      coordinates: d.reach.map (r) ->
        [r.location.longitude, r.location.latitude]

    points.coordinates.push startPos
    points.coordinates.push opos

    c = d3.geo.centroid(points)
    c = [-c[0], -c[1]]

    scale = 40
    bounds = d3.geo.bounds points
    hscale = scale * width  / (bounds[1][0] - bounds[0][0])
    vscale = scale * height / (bounds[1][1] - bounds[0][1])
    scale = if (hscale < vscale) then hscale else vscale

    activeNode = svg.selectAll('.activeNode').data([d])

    activeNode.enter().append('g')
      .classed('activeNode', true)
      .append('circle')

    activeColor = node.select('circle').style('fill')

    activeNode
      .attr('transform', posTrans(projection(opos)))
      .select('circle')
        .style('fill', activeColor)
        .attr('r', d.r)

    sel = reachGroup.selectAll('.reach').data d.reach, (d) -> d.username
    sel.exit().remove()

    enter = sel.enter()
      .append('g')
      .attr('class', 'reach')

    enter.append('line')
      .attr('x1', 0)
      .attr('y1', 0)
      .attr('x2', 0)
      .attr('y2', 0)

    enter.append('circle')
      .attr('r', 4)

    sel.select('line').style('stroke', activeColor)
    sel.select('circle').style('fill', activeColor)

    move = ->
      showOverlay d
      sideoff = [width * 0.4, height * 0.5]
      goTo scale, c, sideoff, 1200

      sel
        .transition().duration(2000)
        #.ease('sin-in-out')
        .tween('pos', (dr) ->
          n = d3.select this
          l = n.select 'line'
          f = d3.geo.interpolate(
            startPos,
            [dr.location.longitude, dr.location.latitude]
          )
          return (t) ->
            p = projection f(t)
            n.attr 'transform', posTrans(p)
            p2 = projection startPos
            activeNode.attr 'transform', posTrans(p2)
            l.attr 'x2', p2[0] - p[0]
            l.attr 'y2', p2[1] - p[1]
        )
        .each('end', -> inDetail = true)

    activeNode.transition().duration(300)
      .tween('pos', ->
        n = d3.select this
        f = d3.geo.interpolate opos, startPos
        return (t) ->
          p = projection f(t)
          n.attr 'transform', posTrans(p)
      )
      .each('end', move)

  drawDots = ->
    pois.each (d) ->
      poi = d3.select this
      poi.attr('transform', (d) -> posTrans(poiPosition(d)))

      ppos = poiPosition(d)
      pack.size(poiSize(d))

      nodes = pack.nodes({children: d.nodes}).filter (d) ->
        d.depth > 0

      ng = poi.selectAll('.node').data(nodes).enter().append('g')
        .attr('class', 'node')
        .style('opacity', 0)
        .on('click', showDetail)

      ng.append('circle')
        .attr('cx', (d) -> d.x)
        .attr('cy', (d) -> d.y)
        .attr('r', (d) -> d.r)
        .style('fill', (d, i) -> nodeColors(i))

  renderMap()
  drawDots()
