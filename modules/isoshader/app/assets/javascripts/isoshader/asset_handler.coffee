### define
libs/request : Request
jquery : $
###

class AssetHandler

  constructor : ->

    @fileCache = {}

    @doneLoading = new $.Deferred()
    @loadAssets()

    return @doneLoading


  loadAssets : ->

    $.when(
      Request.send(url : "/assets/shader/vertexShader.vs"),
      Request.send(url : "/assets/shader/example.fs"),
      Request.send(url : "/assets/shader/fragmentShader.fs"),
      @loadImage(url : "/assets/images/test.png"),
      @loadImage(url : "/assets/images/skel_strongerDT.png")
    ).pipe (vertexShader, isoShader, basicFragShader, texture0, texture1) =>

      @fileCache =
        "vertexShader" : vertexShader[0]
        "isoShader" : isoShader[0]
        "basicFragShader" : basicFragShader[0]
        "texture" : [ texture0, texture1 ]

      @doneLoading.resolve(@)


  loadImage : (options) ->
    #TODO texture resolution

    if options.url

      deferred = new $.Deferred()

      image = new Image()
      image.onload = =>
        deferred.resolve(image)

      image.src = options.url

      deferred


  getFile : (fileName) ->

    if @fileCache.hasOwnProperty(fileName)
      return @fileCache[fileName]
    else
      console.warn("File not found: #{fileName}")