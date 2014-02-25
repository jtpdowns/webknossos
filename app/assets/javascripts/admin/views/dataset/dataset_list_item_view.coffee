### define
underscore : _
backbone.marionette : marionette
###

class DatasetListItemView extends Backbone.Marionette.ItemView


  tagName : "tr"
  attributes : ->
    "data-dataset-name" : @model.get("name")

  template : _.template("""
    <td><%= name %></td>
    <td><%= dataSource.baseDir %></td>
    <td>(
      <%= dataSource.scale[0] %>,
      <%= dataSource.scale[1] %>,
      <%= dataSource.scale[2] %>
      )
    </td>
    <td><%= owningTeam %></td>
    <td class="team-label">
      <% _.map(allowedTeams, function(team){ %>
        <span class="label"><%= team %></span>
      <% }) %>
    </td>
    <td>
      <% if(isActive){ %>
        <i class="fa fa-check"></i>
      <% } else { %>
        <i class="fa fa-times"></i>
      <% } %>
    </td>
    <td>
      <% if(isPublic){ %>
        <i class="fa fa-check"></i>
      <% } else{ %>
        <i class="fa fa-times"></i>
      <% } %>
    </td>
    <td>
    <% _.map(dataSource.dataLayers, function(layer){ %>
        <span class="label"><%= layer.typ %> - <%= layer.elementClass %></span>
    <% }) %>
    <td class="nowrap">
      <% if(dataSource.needsImport){ %>
        <div>
          <a href="/api/datasets/<%= name %>/import" class=" import-dataset">
            <i class="fa fa-plus-circle"></i>import
          </a>
            <div class="progress progress-striped hide">
              <div class="bar" style="width: 0%;"></div>
            </div>
        </div>
      <% } %>
      <% if(isActive){ %>
        <a href="/datasets/<%= name %>/view" >
          <i class="fa fa-eye"></i>view
        </a>
      <% } %>
    </td>
  """)

  events :
    "click .import-dataset" : "startImport"

  ui:
    "importLink" : ".import-dataset"
    "progressbarContainer" : ".progress"
    "progressBar" : ".bar"

  initialize : ->

    @listenTo(@model, "change", @render)

    # In case the user reloads during an import, continue the progress bar
    if @model.get("dataSource").needsImport
      @startImport(null, "GET")


   startImport : (evt, method = "POST") ->

      if evt
        evt.preventDefault()

      $.ajax(
        url : """/api/datasets/#{@model.get("name")}/import"""
        method: method
      ).done( (responseJSON) =>
          if responseJSON.status == "inProgress"
            @ui.importLink.hide()
            @ui.progressbarContainer.show()
            @updateProgress()
      )


    updateProgress : ->

      $.ajax(
        url: "/api/datasets/#{@model.get("name")}/import"
      ).done( (responseJSON) =>
        value = responseJSON.progress * 100
        @ui.progressBar.width("#{value}%")
        if value < 100
          window.setTimeout((=> @updateProgress()), 100)
        else
          @model.fetch()
      )

