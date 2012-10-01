app =
  id: '227417657386928'
  namespace: 'doodoodev'

permissions = [
  'email',
  'user_likes',
  'user_interests',
  'user_questions',
  'publish_actions',
  'publish_stream',
  'friends_interests',
  'create_event'
]

categories = [
  'Interest',
  'Sport',
  'Field of study'
]

Users = new Meteor.Collection 'users'
Interests = new Meteor.Collection 'interests'
Questions = new Meteor.Collection 'questions'
Events = new Meteor.Collection 'events'

if Meteor.isClient
  loginStatus = {}
  currentUser = {}

  window.fbAsyncInit = ->
    FB.init
      appId: app.id
      status: true
      cookie: true
      xfbml: true
      oauth: true

    FB.getLoginStatus (response)->
      console.log response
      if response.status == 'connected'
        loginStatus = response
        app.accessToken = loginStatus.authResponse.accessToken
        getInfo()
        main()
      else
        FB.login (response)->
          if response.authResponse
            console.log 'Welcome!  Fetching your information.... '
            FB.api '/me', (response)->
              console.log "Good to see you, #{response.name}."
              getInfo()
              main()
          else
            console.log 'User cancelled login or did not fully authorize.'
        ,{scope: permissions.join ','}

    getInfo = ->
      FB.api '/me', (user)->
        if user && !user.error
          console.log user
          currentUser = user
          image = document.getElementById 'avatar'
          image.src = "http://graph.facebook.com/#{user.id}/picture"
          name = document.getElementById 'username'
          name.innerHTML = user.name
        else
          console.error user.error.message

  ((d)->
    id = 'facebook-jssdk'
    if d.getElementById(id)
      return
    js = d.createElement 'script'
    js.id = id
    js.async = true
    js.src = '//connect.facebook.net/en_US/all.js'
    d.getElementsByTagName('head')[0].appendChild js
  )(document)

  Template.hello.greeting = ->
    "Welcome to DooDoo."

  Template.hello.events =
    'click input' : ()->
      # template data, if any, is available in 'this'
      if console
        console.log "You pressed the button"

  Interests.fb =
    create: (data, cb)->
      FB.api '/me/interests', 'post', data, (res)-> cb res
    read: (cb)->
      FB.api '/me/interests', (res)-> cb res
    update: (data)->
      FB.api '/me/interests', 'post', data, (res)-> console.log arguments
    delete: (data)->
      FB.api '/me/interests', 'delete', data, (res)-> console.log arguments

  Events.fb =
    create: (title, cb)->
      currentDate = new Date
      FB.api '/me/events', 'post', {
        name: 'Lesson "' + title + '" to start'
        start_time: [currentDate.getFullYear(), currentDate.getMonth() + 1, currentDate.getDay()].join('-')
      }, (res)->
        Events.insert { event_id: res.id, profile_id: currentUser.id }
        cb res
    getAll: ->
      Events.find({profile_id: currentUser.id}).fetch()

  parseInterest = (res)->
    if res?.data?.length
      interests = []
      res.data.filter (item)->
        regexp = new RegExp(categories.join('|'), 'i')
        console.log item.category, 'match:', item.category.match regexp
        if item.category?.match regexp
          interests.push item
      if interests.length
        interests.forEach (item)->
          Interests.insert
            fbUserId: currentUser.id
            points: 0
            name:item.name

  getInterests = -> Interests.fb.read (res)-> parseInterest(res)

  getFriendInterests = (cb)->
    FB.api 'me/friends?fields=interests', (res)->
      console.log 'Friends interests', res
      interests = _.sortBy(_.compact(_.flatten(res.data?.map (friend)-> friend.interests?.data)), 'name')
      Session.set 'friendInterests', interests
      cb interests


  interestDifference = ->
    interests = Interests.find().fetch()
    friendInterests = Session.get 'friendInterests'
    if friendInterests
      diff = friendInterests.filter (item)-> yes if item.name not in _.pluck interests, 'name'
      Session.set 'differentInterests', _.sortBy diff, 'name'
      diff

  interestMatch = ->
    interests = Interests.find().fetch()
    friendInterests = Session.get 'friendInterests'
    if friendInterests
      matched = friendInterests.filter (item)-> yes if item.name in _.pluck interests, 'name'
      Session.set 'matchedInterests', _.sortBy matched, 'name'
      matched

  resolveTabState = ->
    currentTab = Session.get 'currentTab'
    $('.interest-section').each (index, section)->
      console.log section, currentTab
      if section.id == currentTab
        $(section).show()
      else
        $(section).hide()

  main = ->
    console.log 'Main called'

    Session.set 'currentTab', 'my-interests'

    resolveTabState()

    getInterests()
    getFriendInterests (interests)->
      interestDifference()
      interestMatch()

  Template.interestsList.interests = -> Interests.find()
  Template.differenceInterestsList.interests = -> Session.get 'differentInterests'
  Template.matchInterestsList.interests = -> Session.get 'matchedInterests'

  Template.interestsList.events =
#    'click #get-interests': -> getLikes(); getInterests()
#    'click #delete-interests': -> Interests.remove {}
    'click .interest': -> postQuestion(this.name)

if Meteor.isServer
  Meteor.startup ()->
    # code to run on server at startup
