app =
#  id: '227417657386928'
#  namespace: 'doodoodev'
  id: '431649223563866'
  namespace: 'doodoohack'

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
Skills = new Meteor.Collection 'skills'

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
      else
        FB.login (response)->
          if response.authResponse
            console.log 'Welcome!  Fetching your information.... '
            FB.api '/me', (response)->
              console.log "Good to see you, #{response.name}."
              getInfo()
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
          main()
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
        cb res if cb
    getIds: ->
      _.map Events.find({
        profile_id: currentUser.id
      }).fetch(), (item)-> item.event_id
    getAll: (cb)-> FB.api '/?ids=' + Events.fb.getIds().join(','), cb


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

  learnSkill = (interest)->
    Meteor.call 'learnSkill', currentUser.id

  unlearnSkill = (interest)->
    Meteor.call 'unlearnSkill', currentUser.id

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

    id = $('.navigation .active a').attr('id').match(/(.*)-section/)[1]

    $('.interest-section').each (index, section)->
      $(section).hide()
      $('#'+id).show()

  teach = ->
    Meteor.call 'teach', currentUser.id
        
  didEventCreate = (res)->
    Events.fb.getAll (res)->
      Session.set 'myEvents', _.toArray res
    $('#modalEventCreate').modal()

  main = ->
    console.log 'Main called'

    Session.set 'currentTab', 'my-interests'

    resolveTabState()

    getInterests()
    getFriendInterests (interests)->
      interestDifference()
      interestMatch()

    Events.fb.getAll (res)->
      Session.set 'myEvents', _.toArray res


  Template.navigation.events =
    'click a': (event)->
      event.preventDefault()
      $('.navigation .active').removeClass('active')
      id = $(event.target).attr('id').match(/(.*)-section/)[1]
      console.log id
      $(event.target).parent('li').addClass('active')
      $('.interest-section').hide()
      $('#'+id).show()

  Template.interestsList.interests = -> Interests.find()
  Template.differenceInterestsList.interests = -> Session.get 'differentInterests'
  Template.differenceInterestsList.events =
    'click .create-event': -> Events.fb.create(this.name, didEventCreate)
    'click .add-to-my-interest': (event)->
      learnSkill(@)
  Template.matchInterestsList.interests = -> Session.get 'matchedInterests'
  Template.myEventList.items = -> Session.get 'myEvents'


  Template.interestsList.events =
#    'click #get-interests': -> getLikes(); getInterests()
#    'click #delete-interests': -> Interests.remove {}
    'click .interest': -> postQuestion(this.name)

  Template.matchInterestsList.events =
    'click .create-event': -> Events.fb.create(this.name, didEventCreate)

  Template.userBox.events =
    'click #logout': ->
      FB.logout ()-> window.location.reload()

if Meteor.isServer
  graph = "https://graph.facebook.com"
  appSecret = "31aab97e2878f7a4e7c879ea64d63b7e"

  parseToken = (tokenData)->
    tokenData.match(/access_token=(.*)$/)[1]

  FB =
    getAccessToken: (cb)->
      data =
        params:
          grant_type: 'client_credentials'
          client_id: app.id
          client_secret: appSecret
      Meteor.http.get "#{graph}/oauth/access_token", data, (err, res)->
        console.log res
        cb parseToken(res.content)
    api: (url, method, data, cb)->
      thrown new Error('You need to call with url') if not url
      Meteor.http.call method, url, data, cb

  Meteor.startup ()->
    Meteor.methods
      learnSkill: (userId)->
        userId ?= 'me'
        FB.getAccessToken (token)->
          data =
            params:
              access_token: token
              skill: "http://samples.ogp.me/227914737337220"
          Meteor.http.post "#{graph}/#{userId}/#{app.namespace}:learn", data, ()->
            console.log arguments
      unlearnSkill: (userId)->
        userId ?= 'me'
        FB.getAccessToken (token)->
          data =
            params:
              access_token: token
              skill: "http://samples.ogp.me/227914737337220"
          Meteor.http.delete "#{graph}/#{userId}/#{app.namespace}:learn", data, ()->
            console.log arguments
      teach: (userId)->
        userId ?= 'me'
        FB.getAccessToken (token)->
          data =
            params:
              access_token: token
              profile: "http://samples.ogp.me/390580850990722"
          Meteor.http.post "#{graph}/#{userId}/#{app.namespace}:teach", data, ()->
            console.log arguments
