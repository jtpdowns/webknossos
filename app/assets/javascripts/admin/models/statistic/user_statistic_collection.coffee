### define
underscore : _
backbone : backbone
###

class UserStatisticCollection extends Backbone.Collection

  url : "/api/statistics/users"

  parse : (responses) ->

    return responses.map((response) ->

      if _.isEmpty(response.tracingTimes)
        response.tracingTimes.push(tracingTime: 0)

      return response
    )

