_                    = require("underscore")
Backbone             = require("backbone")
PaginationCollection = require("../pagination_collection")

class WorkloadCollection extends PaginationCollection

  url : "/api/tasks/workload"

  paginator_ui :
    perPage : 20

module.exports = WorkloadCollection
