if Meteor.isClient
  Template.hello.greeting = ->
    "Welcome to DooDoo."

  Template.hello.events =
    'click input' : ()->
      # template data, if any, is available in 'this'
      if console
        console.log "You pressed the button"

if Meteor.isServer
  Meteor.startup ()->
    # code to run on server at startup
