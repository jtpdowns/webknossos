### define
underscore : _
backbone : Backbone
./dashboard_task_model : DashboardTaskModel
./user_model : UserModel
admin/models/dataset/dataset_collection : DatasetCollection
dashboard/models/logged_time_model : LoggedTimeModel
admin/models/pagination_collection : PaginationCollection
###

class DashboardModel extends Backbone.Model

  urlRoot : ->

    if userID = @get("userID")
      return "/api/users/#{userID}/annotations"
    else
      return "/api/user/annotations"


  newTaskUrl : "/user/tasks/request"
  defaults :
      showFinishedTasks : false

  initialize : (options) ->

    @set("tasks", new Backbone.Collection())
    @listenTo(@, "sync", @transformToCollection)


  fetch : ->

    promises = [super(arguments)]

    user = new UserModel(id : @get("userID"))
    @set("user", user)

    promises.push(user.fetch())

    # TODO: decide whether these submodels should be loaded at this time

    @set("dataSets", new DatasetCollection())
    @set("loggedTime", new LoggedTimeModel(userID : @get("userID")))

    return $.when.apply($, promises)


  getFinishedTasks : (isFinished = true)->

    filteredTasks = @get("tasks").filter( (task) -> return isFinished == task.get("annotation").state.isFinished )
    return new PaginationCollection(filteredTasks)


  getUnfinishedTasks : ->

    return @getFinishedTasks(false)


  getAnnotations : ->
    @get("allAnnotations")


  createCollection: (name) ->
    collection = new Backbone.Collection()
    # Display newst first.
    collection.sortBy("created")
    collection.add(@get(name))
    @set(name, collection)


  transformToCollection : ->

    tasks = _.filter(@get("taskAnnotations").map( (el) ->
      return DashboardTaskModel::parse(el)
    ))

    tasks = new PaginationCollection(tasks, model : DashboardTaskModel )
    tasks.bootstrap()
    @set("tasks", tasks)

    @createCollection("allAnnotations")


  getNewTask : ->

    newTask = new DashboardTaskModel()

    return newTask.fetch(
      url : @newTaskUrl
      success : (response) =>
        @get("tasks").add(newTask)
    )
