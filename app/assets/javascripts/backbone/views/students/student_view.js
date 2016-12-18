const StudentView = Backbone.View.extend({
  tagName: 'li',

  initialize: function(options) {
    console.log("In StudentView.initialize()");

    // TODO: Compile once
    this.template = _.template($('#student-template').html());

    // Re-render whenever the model changes
    this.listenTo(this.model, 'change', this.render);

    // Cards should always be ready to place on the page
    this.render();
  },

  render: function() {
    var contents = this.template(this.model.attributes);
    this.$el.html(contents);

    // Re-bind events
    this.delegateEvents();

    // Enable chained calls
    return this;
  },

  events: {

  }
})
