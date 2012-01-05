Model ?= {}

Model.Binary =

	vertexTemplate : null
	
	initialize : (callback) ->
		
		@startInitializing callback

		request
			url : '/binary/model/cube'
			responseType : 'arraybuffer'
			,	
			(err, data) =>
				
				callback = @endInitializing err
				
				unless err
					@vertexTemplate = new Int8Array(data)
					callback null
				
				return

	rotateAndTranslate : (data, moveVector, axis, callback) ->
		
		output = new Float32Array(data.length)
		axis = V3.normalize axis


		unless axis[0] == 0 and axis[1] == 1 and axis[2] == 0
			
			mat = M4x4.makeRotate V3.angle([0,1,0], axis), [axis[2], 0, -axis[0]]
			mat = M4x4.translateSelf moveVector, mat
		
			_.defer -> 
				callback null, M4x4.transformPointsAffine(mat, data, output)

		
		else

			[px, py, pz] = moveVector
			
			for i in [0...data.length] by 3
				output[i]     = px + data[i]
				output[i + 1] = py + data[i + 1]
				output[i + 2] = pz + data[i + 2]

			_.defer -> callback null, output
	
	get2 : (coordinates, callback) ->

		output = new Float32Array(~~(coordinates.length / 3))

		linear = (p0, p1, d) ->
			p0 * (1 - d) + p1 * d
		
		bilinear = (p0, p1, p2, p3, d0, d1) ->
			p0 * (1 - d0) * (1 - d1) + 
			p1 * d0 * (1 - d1) + 
			p2 * (1 - d0) * d1 + 
			p3 * d0 * d1
		
		trilinear = (p0, p1, p2, p3, p4, p5, p6, p7, d0, d1, d2) ->
			p0 * (1 - d0) * (1 - d1) * (1 - d2) +
			p1 * d0 * (1 - d1) * (1 - d2) + 
			p2 * (1 - d0) * d1 * (1 - d2) + 
			p3 * (1 - d0) * (1 - d1) * d2 +
			p4 * d0 * (1 - d1) * d2 + 
			p5 * (1 - d0) * d1 * d2 + 
			p6 * d0 * d1 * (1 - d2) + 
			p7 * d0 * d1 * d2

		for i in [0...coordinates.length] by 3

			x = coordinates[i]
			y = coordinates[i + 1]
			z = coordinates[i + 2]

			x0 = x >> 0; x1 = x0 + 1; xd = x - x0			
			y0 = y >> 0; y1 = y0 + 1;	yd = y - y0
			z0 = z >> 0; z1 = z0 + 1; zd = z - z0

			output[i / 3] = if x0 == x
				if y0 == y
					if z0 == z
						value(x, y, z)
					else
						#linear z
						linear(value(x, y, z0), value(x, y, z1), zd)
				else
					if z0 == z
						#linear y
						linear(value(x, y0, z), value(x, y1, z), yd)
					else
						#bilinear y,z
						bilinear(value(x, y0, z0), value(x, y1, z0), value(x, y0, z1), value(x, y1, z1), yd, zd)
			else
				if y0 == y
					if z0 == z
						#linear x
						linear(value(x0, y, z), value(x1, y, z), xd)
					else
						#bilinear x,z
						bilinear(value(x0, y, z0), value(x1, y, z0), value(x0, y, z1), value(x1, y, z1), xd, zd)
				else
					if z0 == z
						#bilinear x,y
						bilinear(value(x0, y0, z), value(x1, y0, z), value(x0, y1, z), value(x1, y1, z), xd, yd)
					else
						#trilinear x,y,z
						trilinear(
							value(x0, y0, z0),
							value(x1, y0, z0),
							value(x0, y1, z0),
							value(x1, y1, z0),
							value(x0, y0, z1),
							value(x1, y0, z1),
							value(x0, y1, z1),
							value(x1, y1, z1),
							xd, yd, zd
						)
		
		callback(null, output)

	get : (position, direction, callback) ->
		
		@lazyInitialize (err) =>
			return callback err if err

			loadedData = []
			
			finalCallback = (err, vertices, colors) ->
				if err
					callback err
				else
					colorsFloat = new Float32Array(colors.length)
					colorsFloat[i] = colors[i] / 255 for i in [0...colors.length]
					callback null, vertices, colorsFloat


			@rotateAndTranslate @vertexTemplate, position, direction, @synchronizingCallback(loadedData, finalCallback)

			@load position, direction, @synchronizingCallback(loadedData, finalCallback)

				

	load : (point, direction, callback) ->
		@lazyInitialize (err) ->
			return callback(err) if err

			request
				url : "/binary/data/cube?px=#{point[0]}&py=#{point[1]}&pz=#{point[2]}&ax=#{direction[0]}&ay=#{direction[1]}&az=#{direction[2]}"
				responseType : 'arraybuffer'
				,
				(err, data) ->
					if err
						callback err
					else
						callback null, new Uint8Array(data) 


Model.Mesh =
	
	get : (name, callback) ->

		unless @tryCache name, callback

			request url : "/assets/mesh/#{name}", responseType : 'arraybuffer', (err, data) =>
				if err
					callback err 

				else
					try
						header  = new Uint32Array(data, 0, 3)
						coords  = new Float32Array(data, 12, header[0])
						colors  = new Float32Array(data, 12 + header[0] * 4, header[1])
						indexes = new Uint16Array(data, 12 + 4 * (header[0] + header[1]), header[2])

						@cachingCallback(name, callback)(null, coords, colors, indexes)

					catch ex
						callback(ex)

Model.Pointcloudmesh =
	
	get : (width, callback) ->

		try
			# *3 coords per point
			verticesArraySize = (width)*(width)*3

			vertices = new Uint16Array(verticesArraySize)

			# *2 because two triangles per point and 3 points per triangle
			triangles = new Uint16Array(verticesArraySize*2)
			currentPoint = 0
			currentIndex = 0

			#iterate through all points
			for y in [0..width - 1]
				for x in [0..width - 1]
					# < width -1: because you don't draw a triangle with
					# the last points on each axis.
					if y < (width - 1) and x < (width - 1)
						triangles[currentIndex*2 + 0] = currentPoint
						triangles[currentIndex*2 + 1] = currentPoint + 1 
						triangles[currentIndex*2 + 2] = currentPoint + width
						triangles[currentIndex*2 + 3] = currentPoint + width
						triangles[currentIndex*2 + 4] = currentPoint + width + 1
						triangles[currentIndex*2 + 5] = currentPoint + 1
					
						vertices[currentIndex + 0] = x
						vertices[currentIndex + 1] = y
						vertices[currentIndex + 2] = 0

					currentPoint++
					currentIndex += 6

			callback(null, vertices, triangles)
		catch ex
			callback(ex)

Model.Shader =

	get : (name, callback) ->
		
		unless @tryCache name, callback
		
			loadedData = []
			request url : "/assets/shader/#{name}.vs", (@synchronizingCallback loadedData, (@cachingCallback name, callback))
			request url : "/assets/shader/#{name}.fs", (@synchronizingCallback loadedData, (@cachingCallback name, callback))

	
Model.Route =
	
	dirtyBuffer : []
	route : null
	startDirection : null
	startPosition : null
	id : null

	initialize : (callback) ->

		@startInitializing callback

		request
			url : '/route/initialize'
			,
			(err, data) =>
				
				callback = @endInitializing err
				
				unless err
					try
						data = JSON.parse data

						@route = [ data.position ]
						@id = data.id
						@startDirection = data.direction
						@startPosition = data.position
						
						callback null, data.position, data.direction
					catch ex
						callback ex
	
	pull : ->
		request	url : "/route/#{@id}", (err, data) =>
			unless err
				@route = JSON.parse data


	push : ->
		@push = _.throttle2 @_push, 30000
		@push()

	_push : ->
		unless @pushing
			@pushing = true

			@lazyInitialize (err) =>
				return if err

				transportBuffer = @dirtyBuffer
				@dirtyBuffer = []
				request
					url : "/route/#{@id}"
					contentType : 'application/json'
					method : 'POST'
					data : transportBuffer
					,
					(err) =>
						@pushing = false
						if err
							@dirtyBuffer = transportBuffer.concat @dirtyBuffer
							@push()
	
	put : (position, callback) ->
		
		@lazyInitialize (err) =>
			return callback(err) if err

			@route.push position
			@dirtyBuffer.push position
			@push()

Model.LazyInitializable =
	
	initialized : false

	lazyInitialize : (callback) ->
		unless @initialized
			if @waitingForInitializing?
				@waitingForInitializing.push callback
			else
				@initialize callback
		else
			callback null
	
	startInitializing : (callback) ->
		@waitingForInitializing = [ callback ]
	
	endInitializing : (err) ->
		callbacks = @waitingForInitializing
		delete @waitingForInitializing
		
		callback = (args...) ->
			cb(args...) for cb in callbacks
			return

		if err
			callback err
			return
		else
			@initialized = true
			return callback

Model.Synchronizable = 	

	synchronizingCallback : (loadedData, callback) ->
		loadedData.push null
		loadedData.counter = loadedData.length
		i = loadedData.length - 1

		(err, data) ->
			if err
				callback err unless loadedData.errorState
				loadedData._errorState = true
			else
				loadedData[i] = data
				unless --loadedData.counter
					callback null, loadedData...

Model.Cacheable =
	
	cache : {}

	cachingCallback : (cache_tag, callback) ->
		(err, args...) =>
			if err
				callback err
			else
				@cache[cache_tag] = args
				callback null, args...
	
	tryCache : (cache_tag, callback) ->
		if (cached = @cache[cache_tag])?
			_.defer -> callback null, cached...
			return true
		else
			return false



_.extend Model.Binary, Model.Synchronizable
_.extend Model.Binary, Model.LazyInitializable
_.extend Model.Mesh, Model.Cacheable
_.extend Model.Shader, Model.Synchronizable
_.extend Model.Shader, Model.Cacheable
_.extend Model.Route, Model.LazyInitializable
