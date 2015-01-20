### define
libs/request : Request
underscore : _
backbone : Backbone
backbone-deep-model : DeepModel
###

class DatasetConfiguration extends Backbone.DeepModel


  initialize : ({datasetName}) ->

    @url = "/api/dataSetConfigurations/#{datasetName}"
    @listenTo(this, "change", -> @save())


  reset : =>

    Request.send(
      url : "/api/dataSetConfigurations/default"
      dataType : "json"
    ).done( (defaultData) =>
      @set("brightness", defaultData.brightness)
      @set("contrast", defaultData.contrast)
    )
