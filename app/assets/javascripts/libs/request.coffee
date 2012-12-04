### define ###

Request = 

  send : (options) ->

    options.type ||= options.method

    if options.dataType == "blob" or options.dataType == "arraybuffer"
      
      deferred = $.Deferred()

      return deferred.reject("No url defined").promise() unless options.url

      _.defaults(options, type: "GET", data: null)

      options.type = "POST" if options.type == "GET" and options.data

      xhr = new XMLHttpRequest()
      xhr.open options.type, options.url, true
      xhr.responseType = options.dataType 
      xhr.setRequestHeader("Content-Type", options.contentType) if options.contentType

      if options.formData? and not options.data
        options.data = new FormData()
        options.data.append(key, value) for key, value of options.formData

      xhr.onload = ->
        if @status == 200
          deferred.resolve(@response)
        else
          deferred.reject(@statusText)
      
      xhr.onerror = (err) ->
        deferred.reject(err)

      xhr.send(options.data)

      deferred.promise()
    
    else
      
      if options.data
        options.data = JSON.stringify(options.data)
        options.contentType = "application/json" unless options.contentType
      
      $.ajax(options)