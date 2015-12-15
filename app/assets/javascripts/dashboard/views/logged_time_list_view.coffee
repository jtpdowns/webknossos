_           = require("lodash")
marionette  = require("backbone.marionette")
moment      = require("moment")
FormatUtils = require("format_utils")

class LoggedTimeListView extends Backbone.Marionette.ItemView

  template : _.template("""
    <table class="table-striped table-hover table">
      <thead>
        <tr>
          <th>Month</th>
          <th>Worked Hours</th>
        </tr>
      </thead>
      <tbody>
        <% items.forEach(function(item) { %>
          <tr>
            <td><%= moment(item.interval).format("MM/YYYY") %></td>
            <td><%= FormatUtils.formatSeconds(item.time.asSeconds()) %></td>
          </tr>
        <% }) %>
      </tbody>
    </table>
  """)

  templateHelpers :
    FormatUtils : FormatUtils
    moment : moment

module.exports = LoggedTimeListView
