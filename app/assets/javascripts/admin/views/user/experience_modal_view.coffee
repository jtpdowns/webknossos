### define
underscore : _
backbone.marionette : marionette
###

class ExperienceModal extends Backbone.Marionette.ItemView

  tagName : "div"
  className : "modal hide fade"
  template : _.template("""
    <div class="modal-header">
      <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
      <h3>Change Experience</h3>
    </div>
    <div class="modal-body form-horizontal">
      <div class="control-group">
        <label class="control-label" for="experience-domain">Domain</label>
        <div class="controls">
          <input type="text" class="input-small" name="experience-domain" autocomplete="off" required>
        </div>
      </div>
      <div class="control-group">
        <label class="control-label" for="experience-value">Value</label>
        <div class="controls">
          <input type="number" class="input-small" name="experience-value" value="0">
        </div>
      </div>
    </div>
    <div class="modal-footer">
      <a href="#" class="increase-experience btn btn-primary">
      Increase Experience
      </a>
      <a href="#" class="set-experience btn btn-primary">
        Set Experience
      </a>
      <a href="#" class="delete-experience btn btn-primary">
        Delete Experience
      </a>
      <a href="#" class="btn" data-dismiss="modal">Cancel</a>
    </div>
  """)

  events :
    "click .set-experience" : "setExperience"
    "click .delete-experience" : "deleteExperience"
    "click .increase-experience" : "changeExperience"


  ui :
    "experienceValue" : "input[type=number]"
    "experienceDomain" : "input[type=text]"

  initialize : (args) ->

    @userCollection = args.userCollection


  setExperience : ->

    if @isValid()
      @changeExperience(true)
    return


  deleteExperience : ->

    if @isValid()

      domain = @ui.experienceDomain.val()
      users = @findUsers()

      for user in users
        experiences = user.get("experiences")
        if _.isNumber(experiences[domain])
          delete experiences[domain]

        user.save("experiences" : experiences)
        user.trigger("change") #Backbone doesn't support nested models

        @hideModal()

    return


  changeExperience : (setOnly) ->

    if @isValid()

      domain = @ui.experienceDomain.val()
      value = +@ui.experienceValue.val()
      users = @findUsers()

      for user in users
        experiences = user.get("experiences")
        if _.isNumber(experiences[domain]) and not setOnly
          experiences[domain] += value
        else
          experiences[domain] = value
        user.save("experiences" : experiences)
        user.trigger("change") #Backbone doesn't support nested models

        @hideModal()

    return


  findUsers : ->

    users = $("tbody input[type=checkbox]:checked").map((i, element) =>
      return @userCollection.findWhere(
        id: $(element).val()
      )
    )
    return users


  isValid : ->

    isValid = @ui.experienceDomain.val().trim() != ""

    # Highlight the domain textbox if it is empty
    unless isValid
      @ui.experienceDomain.focus()

    return isValid

  hideModal : ->

    @$el.modal("hide")
