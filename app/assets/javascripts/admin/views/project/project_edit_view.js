import _ from "lodash";
import app from "app";
import FormSyphon from "form-syphon";
import Marionette from "backbone.marionette";
import Toast from "libs/toast";

class ProjectEditView extends Marionette.View {
  static initClass() {
    this.prototype.template = _.template(`\
<div class="row">
  <div class="col-sm-12">
    <div class="well">
      <div class="col-sm-9 col-sm-offset-2">
        <h3>Update project</h3>
      </div>
  
      <form method="POST" class="form-horizontal">
        <div class="form-group">
          <label class="col-sm-2" for="team">Team</label>
          <div class="col-sm-10 team">
            <input type="text" class="form-control" name="team" value="<%= team %>" required autofocus disabled>
          </div>
        </div>
        <div class="form-group">
          <label class="col-sm-2 for="name">Project Name</label>
          <div class="col-sm-10">
            <input type="text" class="form-control" name="name" value="<%= name %>" required autofocus disabled>
          </div>
        </div>
        <div class="form-group">
          <label class="col-sm-2 for="owner">Owner</label>
          <div class="col-sm-10 owner">
            <input type="text" class="form-control" name="owner" value="<%= owner.firstName %> <%= owner.lastName %>" required autofocus disabled>
          </div>
        </div>
        <div class="form-group">
          <label class="col-sm-2 for="priority">Priority</label>
          <div class="col-sm-10">
            <input type="number" class="form-control" name="priority" value="<%= priority %>" required>
          </div>
        </div>
        <div class="form-group">
          <div class="col-sm-2 col-sm-offset-9">
          <button type="submit" class="form-control btn btn-primary">Update</button>
          </div>
        </div>
      </form>
    </div>
  </div>
</div>\
`);

    this.prototype.className = "container wide project-administration";
    this.prototype.events =
      { "submit form": "submitForm" };

    this.prototype.ui =
      { form: "form" };
  }


  initialize() {
    this.listenTo(this.model, "sync", this.render);
    return this.model.fetch();
  }


  submitForm(event) {
    event.preventDefault();

    if (!this.ui.form[0].checkValidity()) {
      Toast.error("Please supply all needed values.");
      return;
    }

    const formValues = FormSyphon.serialize(this.ui.form);
    formValues.owner = this.model.get("owner").id;

    return this.model.save(formValues).then(
      () => {},
      Toast.success("Saved!"),
      app.router.loadURL(`/projects#${this.model.get("name")}`),
    );
  }
}
ProjectEditView.initClass();


export default ProjectEditView;