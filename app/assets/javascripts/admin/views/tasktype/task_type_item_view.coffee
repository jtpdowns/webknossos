### define
underscore : _
backbone.marionette : marionette
libs/toast : Toast
./simple_task_item_view : SimpleTaskItemView
###

class TaskTypeItemView extends Backbone.Marionette.CompositeView

  template : _.template("""
    <tr id="@taskType.id">
      <td class="details-toggle"
        href="@controllers.admin.routes.TaskAdministration.tasksForType(taskType.id)"
        data-ajax="add-row=#@taskType.id+tr"> <i class="caret-right"></i><i class="caret-down"></i></td>
      <td> @formatHash(taskType.id) </td>
      <td> @taskType.team </td>
      <td> @taskType.summary </td>
      <td> @formatShortText(taskType.description) </td>
      <td>
        @taskType.settings.allowedModes.map{ mode =>
          <span class="label label-default"> @mode.capitalize </span>
        }
      </td>
      <td>
        @if(taskType.settings.branchPointsAllowed) {
          <span class="label label-default"> Branchpoints </span>
        }
        @if(taskType.settings.somaClickingAllowed) {
          <span class="label label-default"> Soma clicking </span>
        }
      </td>
      <td> @taskType.expectedTime </td>
      <td> @taskType.fileName.getOrElse("") </td>
      <td class="nowrap">
        <a href="@controllers.routes.AnnotationController.trace(AnnotationType.CompoundTaskType, taskType.id)" title="view all finished tracings"><i class="fa fa-random"></i>view</a><br />
        <a href="@controllers.admin.routes.TaskTypeAdministration.edit(taskType.id)" ><i class="fa fa-pencil"></i>edit </a> <br />
        <a href="@controllers.admin.routes.TaskTypeAdministration.delete(taskType.id)" data-ajax="delete-row,confirm"><i class="fa fa-trash-o"></i>delete </a>
      </td>
    </tr>
    <tr class="details-row" >
      <td colspan="12">
        <table class="table table-condensed table-nohead">
          <tbody> <!-- class="hide" -->
            <!-- TASKS FOR TASKTYPE NEED TO BE LOADED INTO THIS TABLE -->
          </tbody>
        </table>
      </td>
    </tr>
  """)

  itemView : SimpleTaskItemView
  itemViewContainer : "tbody"
  tagName : "tbody"
