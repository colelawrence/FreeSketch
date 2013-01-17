# Free Canvas for Molly

$ = Zepto

connection = 0
ctx = 0
gm = null
tools = null
gameStarted = false
inputOpen = false
sizeOutOfDate = false
colorOutOfDate = false
client_id = null
uname = ""

$ ->
  wsUri = "ws://192.168.0.2:236/"
  #wsUri = "ws://70.94.89.253:236/"
  console.log("Creating new Socket at: "+wsUri)
  wss = new window.WebSocket(wsUri)
  connection = new Connection(wss)

getConnection= ->
  connection
getUsername= ->
  uname
getId= ->
  if client_id == null
    client_id = makeID()
  return client_id
  
refreshCanvas= ->
  gm.run()

saveCanvas= ->
  canvas = document.getElementById("sketchpad")
  img = canvas.toDataURL("image/png")
  removeCanvasSaver()
  $('body').append('<div id="save-canvas" class="span8" onclick="closeInput();"><img src="'+img+'"/><h4>Right click to save</h4></div>');

removeCanvasSaver= ->
  $('#save-canvas').remove()

makeID= ->
  text = ""
  possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  text += possible.charAt(Math.floor(Math.random() * possible.length))
  text += possible.charAt(Math.floor(Math.random() * possible.length))
  text += possible.charAt(Math.floor(Math.random() * possible.length))
  return text

startGame= ->
  canvas = document.createElement("canvas")
  game = new Game(canvas)
  canvas.height = game.viewHeight
  canvas.width = game.viewWidth
  canvas.id = "sketchpad"
  $('.g').text('')
  $('.g').append(canvas)
  game.run()
  listeners = new Listeners(game)
  gm = game
  tools = new Toolbar(gm)
  gameStarted = true

delay = (ms, func) -> setTimeout func, ms

updateColor= ->
  tools.changeColor(tools.colorInput.getValue()/100,1,tools.lumInput.getValue()/100)
  colorOutOfDate = false
updateLumInput= ->
  tools.updateLumInput()
updateSize= ->
  tools.changeSize(Math.floor(tools.sizeInput.getValue()/100 * 12))
  sizeOutOfDate = false

openNotice = (evt) ->
  if !inputOpen
    openInput()
    inputOpen = true
    if evt.keyCode == 32
      $('#inputBox').val('')
  if evt.keyCode == 13
    sendAndClear()
    closeInput()

openInput= ->
  $('#largeInput').attr('style','visibility: visible;')
  $('#lightBox').attr('style','visibility: visible;')
  $('#inputBox').focus()

closeInput= ->
  $('#largeInput').attr('style','visibility: hidden;')
  $('#lightBox').attr('style','visibility: hidden;')
  removeCanvasSaver()
  updateColor() if colorOutOfDate
  updateSize() if sizeOutOfDate
  $('#inputBox').val('')
  inputOpen = false

sendAndClear= ->
  if $('#inputBox').val() != ''
    connection.sendMessage(getUsername(), $('#inputBox').val()) 
    appendSent($('#inputBox').val())
    $('#inputBox').val('')

class Pencil
  lastX: 0
  lastY: 0
  size: 1
  color: '#000'
  drawing: false
  constructor:(@cid)->


pencilBox = []

addPencil=(cid)->
  pencilBox.push(new Pencil(cid))
  gm.newCursor(cid)
  getPencil(cid)

removePencil=(cid)->
  gm.removeCursor(cid)
  delete getPencil(cid)

getPencil= (cid) ->
  for pencil in pencilBox
    return pencil if pencil.cid == cid
  addPencil(cid)

drawSData = (d) ->
  return if !gameStarted
  cid = d[0]
  pencil = getPencil(cid)
  return if pencil == null or typeof pencil == 'undefined'
  x2 = d[1]
  y2 = d[2]
  #Mouse pointer stuff
  gm.drawCursor(cid,x2, y2)
  gm.drawIn(pencil.size, pencil.color, pencil.lastX, pencil.lastY, x2, y2) if pencil.drawing
  pencil.lastX = x2
  pencil.lastY = y2

pickupAPencil = (cid) ->
  getPencil(cid).drawing = false
putdownAPencil = (cid) ->
  getPencil(cid).drawing = true

changePencil= (d) ->
  cid = d[1]
  newsize = d[2]
  newcolor = d[3]
  pencil = getPencil(cid)
  pencil.size = newsize
  pencil.color = newcolor

serverMessage = (d) ->
  $('#messagelog').prepend(
    '<li class="msg"><span style="color:#f3f">Server: </span>'+d[1].replace('`',':')+'</li>');

userConnection = (d) ->
  $('#messagelog').prepend(
    '<li class="msg"><span style="color:#4f4">Artist Joined: </span>'+d[1]+'</li>');
  addPencil(d[2])

messageData = (d) ->
  $('#messagelog').prepend(
    '<li class="msg selectable"><span style="color:#f33">'+d[1]+': </span>'+d[2].replace('`',':')+'</li>');

appendSent = (m) ->
  $('#messagelog').prepend(
    '<li class="msg selectable"><span style="color:#33f">'+getUsername()+': </span>'+m+'</li>');

getCookie = (cookieKey) ->
  pageCookies = document.cookie.split(";")
  for cookie in pageCookies
    cookieKV = cookie.split("=")
    console.log(cookieKV)
    if(cookieKV[0] == cookieKey)
      return unescape(cookieKV[1])
  return null

setCookie= (cookieKey, cookieValue, exdays) ->
  exdate = new Date()
  exdate.setDate(exdate.getDate() + exdays)
  c_value = escape(cookieValue) + if exdays == null then "" else "; expires=" + exdate.toUTCString()
  document.cookie = cookieKey + "=" + c_value

checkUsername= ->
  username = getCookie("username")
  if username == null or username == ""
    username=prompt("Please enter your name:","")
    alert('You can press any key to open the chat menu and change your pencils!')
    if username != null and username != ""
      setCookie("username", username, 21)
  uname = username

setUsername= ->
  username=prompt("Please enter your name:","")
  if username != null and username != ""
    setCookie("username", username, 21)
    uname = username

class Game
  viewWidth: 840
  viewHeight: 640
  positionX: 0
  positionY: 0
  pencilOutOfDate: false
  uSize: 1
  uColor: "#000"

  x1: 0
  y1: 0

  constructor: (@canvas) ->
    @ctx = @canvas.getContext("2d")
    @ctx.lineWidth = 1
    @ctx.strokeStyle = "#000"
    @ctx.lineCap = 'round'

  run: ->
    @ctx.fillStyle = "#f2f2f2"
    @ctx.fillRect(0,0,@viewWidth,@viewHeight)
    @ctx.lineCap = 'round'

  position: ->
    if(@canvas && !isNaN(@canvas.offsetLeft) && !isNaN(@canvas.offsetTop))
      @positionX = @canvas.offsetLeft - window.scrollX
      @positionY = @canvas.offsetTop - window.scrollY

  pickupPencil: ->
    @x1 = 0
    @y1 = 0
    getConnection().sendPickup()

  drawCursor: (cid,x,y) ->
    #console.log("cid: "+cid+" X:"+x+" Y:"+y)
    $('#'+cid).attr('style','top: '+y+'px; left: '+x+'px;')
  
  newCursor: (cid) ->
    if $('#'+cid).get().length != 0
      console.log("Pencil cursor REPEATED CID ERROR")
      return
    else
      $('#cursors').append(
        '<div id="'+cid+'" class="curs" style="top: 0px;left: 0px;"></div>');
  removeCursor: (cid) ->
    console.log("Cursor with CID:"+cid+" removed")
    $('#'+cid).remove()

  draw: (x2,y2) ->
    aX = @x1
    aY = @y1
    bX = Math.floor(x2)
    bY = Math.floor(y2)
    @x1 = bX
    @y1 = bY
    @ctx.lineWidth = @uSize
    @ctx.strokeStyle = @uColor
    @drawStep2(aX,aY,bX,bY)
    getConnection().sendPencil(@uSize,@uColor) if @pencilOutOfDate
    getConnection().sendDraw(bX,bY)

  cmove: (x2, y2) ->
    bX = Math.floor(x2)
    bY = Math.floor(y2)
    getConnection().sendDraw(bX,bY)
    
  drawIn: (bSize, bColor, aX, aY, bX, bY) ->
    @ctx.lineWidth = bSize
    @ctx.strokeStyle = bColor
    @drawStep2(aX,aY,bX,bY)

  drawStep2: (aX,aY,bX,bY) ->
    if aX == 0 and aY == 0
      return getConnection().sendPutdown()
    @ctx.beginPath()
    @ctx.moveTo(aX,aY)
    @ctx.lineTo(bX,bY)
    @ctx.stroke()
    
    

class Listeners
  drawing: false
  constructor: (@game) ->
    @game.position()
    window.addEventListener 'resize', () =>
      @game.position()
    window.addEventListener 'scroll', () =>
      @game.position()
    @game.canvas.addEventListener 'mouseup', () =>
      @pickupPencil()
    @game.canvas.addEventListener 'mousedown', () =>
      @drawing = true
    @game.canvas.addEventListener 'mouseout', () =>
      @pickupPencil()
    @game.canvas.addEventListener 'mousemove', (e) =>
      x = e.clientX - @game.positionX
      y = e.clientY - @game.positionY
      if(!@drawing)
        @game.cmove(x,y)
      else
        @game.draw(x,y)
  pickupPencil: ->
    @drawing = false;
    @game.pickupPencil()

class Connection
  constructor: (@wss) ->
    console.log("Connection initialized.")
    @wss.onopen= ->
      console.log("Connection opened, starting game.")
      startGame()
      getConnection().Send("u:"+checkUsername()+":"+getId())
    @wss.onmessage= (evt)-> getConnection().Receive(evt)

  Receive: (msg) ->
    dA = msg.data.split(":")
    if dA[0] == 'b'
      return changePencil(dA)
    if dA[0] == 'p'
      return pickupAPencil(dA[1])
    if dA[0] == 'd'
      return putdownAPencil(dA[1])
    if dA[0] == 'm'
      return messageData(dA)
    if dA[0] == 's'
      return serverMessage(dA)
    if dA[0] == 'u'
      return userConnection(dA)
    if dA[0] == 'x'
      return removePencil(dA[1])
    drawSData(dA)

  Send: (msg) ->
    @wss.send(msg)

  sendDraw: (x2,y2) ->
    msg=""
    msg += getId()+":"+x2+":"+y2
    @Send(msg)

  sendPencil: (uS, uC) ->
    @Send("b:"+getId()+":"+uS+":"+uC)
  sendPickup: ->
    @Send("p:"+getId())
  sendPutdown: ->
    @Send("d:"+getId())

  sendMessage: (auth, message) ->
    msg=""
    msg += "m:"+auth.replace('`',':')+":"+message.replace('`',':')
    @Send(msg)

class Toolbar
  constructor:(@game)->
    color = $("#color").get(0)
    size = $("#size").get(0)
    lum = $("#lum").get(0)
    @colorInput = new InputSlider(color)
    @sizeInput = new InputSlider(size)
    @lumInput = new InputSlider(lum)
  changeSize:(s)->
    @game.uSize = s
    @game.pencilOutOfDate = true
  updateLumInput: ->
    c = @hslToRgb(tools.colorInput.getValue()/100,1,.5)
    strc = "rgb("+Math.floor(c[0])+","+Math.floor(c[1])+","+Math.floor(c[2])+")";
    $("#lum").attr('style','background-color: '+strc+';')
  changeColor:(h,s,b) ->
    c = @hslToRgb(h,s,b)
    strc = "rgb("+Math.floor(c[0])+","+Math.floor(c[1])+","+Math.floor(c[2])+")";
    console.log(strc);
    @game.uColor = strc
    @game.pencilOutOfDate = true
    
  hue2rgb:(p, q, t) ->
    t += 1 if t < 0
    t -= 1 if t > 1
    return p + (q - p) * 6 * t if t < 1/6 
    return q if t < 1/2
    return p + (q - p) * (2/3 - t) * 6 if t < 2/3
    return p
  hslToRgb:(h, s, l) ->
    if s == 0
      r = g = b = l
    else
      q = if l < 0.5 then l * (1+s) else l+s - l*s
      p = 2 * l - q
      r = @hue2rgb(p, q, h + 1/3)
      g = @hue2rgb(p, q, h)
      b = @hue2rgb(p, q, h - 1/3)
    return [r * 255, g * 255, b * 255]
    
class InputSlider
  viewWidth: 220
  viewHeight: 15
  positionX: 0
  valueByWidth: 110 # [0-220]
  choosing: false
  outOfDate: false

  offsetsLeft:(object, offset)->
    return offset if !object
    offset += object.offsetLeft
    return @offsetsLeft(object.offsetParent, offset)

  constructor:(@canvas)->
    console.log(@canvas)
    @position()
    @ctx = @canvas.getContext("2d")
    @ctx.fillStyle = "#000"
    @canvas.addEventListener 'mouseup', () =>
      @choosing = false
    @canvas.addEventListener 'mousedown', () =>
      @position()
      @choosing = true
    @canvas.addEventListener 'mouseout', () =>
      @choosing = false
    @canvas.addEventListener 'mousemove', (e) =>
      return if !@choosing
      #console.log(e.clientX + ", " + @positionX)
      @valueByWidth = e.clientX - @positionX
      @drawSlide()

  drawSlide: ->
    console.log(@canvas.width + "  " + @valueByWidth)
    @ctx.clearRect(0, 0, @canvas.width, @canvas.height);
    @ctx.fillRect(@valueByWidth - 1, 0, 2, @canvas.height);

  getValue: ->
    Math.floor(@valueByWidth/220 * 100)

  position: ->
    console.log("offset: "+@offsetsLeft(@canvas,0))
    if(@canvas && !isNaN(@canvas.offsetLeft))
      @positionX = @offsetsLeft(@canvas,0) - window.scrollX