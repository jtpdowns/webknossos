### define
underscore : _
backbone.marionette : Marionette
libs/toast : Toast
./project_task_view : ProjectTaskView
admin/models/project/project_task_collection : ProjectTaskCollection
###

class ProjectListItemView extends Backbone.Marionette.CompositeView

  template : _.template("""
    <tr id="<%= name %>">
      <td class="details-toggle" href="/admin/projects/<%= name %>/tasks">
        <i class="caret-right"></i>
        <i class="caret-down"></i>
      </td>
      <td><%= name %></td>
      <td><%= team %></td>
      <td><%= owner.firstName %> <%= owner.lastName %></td>
      <td class="nowrap">
        <a href="/annotations/CompoundProject/<%= name %>" title="View all finished tracings">
          <i class="icon-random"></i>view
        </a><br/>
        <a href="/api/projects/<%= name %>/download" title="Download all finished tracings">
          <i class="icon-download"></i>download
        </a><br/>
        <a href="#" class="delete">
          <i class="icon-trash"></i>delete
        </a>
      </td>
    </tr>
    <tr class="details-row hide" >
      <td colspan="12">
        <table class="table table-condensed table-nohead table-hover">
          <tbody>
          </tbody>
        </table>
      </td>
    </tr>
  """)

  tagName : "tbody"
  itemView : ProjectTaskView
  itemViewContainer : "tbody"

  events :
    "click .delete" : "deleteProject"
    "click .details-toggle" : "toggleDetails"

  ui:
    "detailsRow" : ".details-row"
    "detailsToggle" : ".details-toggle"


  initialize : ->

    @listenTo(app.vent, "projectListView:toggleDetails", @toggleDetails)
    @collection = new ProjectTaskCollection(@model.get("name"))

    # minimize the toggle view on item deletion
    @listenTo(@collection, "remove", (item) =>
      @toggleDetails()
    )


  deleteProject : ->

    if window.confirm("Do you really want to delete this project?")
      xhr = @model.destroy(
        wait : true
        error: @handleXHRError
      )


  toggleDetails : ->

    if @ui.detailsRow.hasClass("hide")

      @collection
        .fetch()
        .done( =>
          @render()
          @ui.detailsRow.removeClass("hide")
          @ui.detailsToggle.addClass("open")
        )
    else
      @ui.detailsRow.addClass("hide")
      @ui.detailsToggle.removeClass("open")


  handleXHRError : (model, xhr) ->

    xhr.responseJSON.messages.forEach(
      (message) ->
        Toast.error(message.error)
    )