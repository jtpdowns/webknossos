_        = require("underscore")
backbone = require("backbone")

class AnnotationModel extends Backbone.Model

  urlRoot : "/annotations/task/"

module.exports = AnnotationModel
