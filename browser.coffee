_ = require "underscore"
backbone = require "backbone"

models = require "./lib/models.coffee"
views = require "./lib/views/index.coffee"

Router = backbone.Router.extend
    routes:
        "users": "users"
        "users/:user": "profile"
        "users/:user/reset/token=:token": "reset"

    users: ( q ) ->
        q ?= ""
        console.log( "USERS -> ADMIN", q )
        collection = new @classes.User.Collection();
        new @classes.AdminView({
            collection: collection
        }).render().$el.appendTo( $( "#main" ).empty() )
        collection.fetch({ data: q });

    profile: ( user ) ->
        console.log( "USERS -> PROFILE" )
        model = new @classes.User({ id: user })
        if user == "self"
            model = models.User.self

        new @classes.ProfileView({
            model: model
        }).render().$el.appendTo( $( "#main" ).empty() )
        model.fetch()


    reset: ( user, token ) ->
        console.log( "USERS -> RESET" )
        model = new @classes.User({ id: user })
        new @classes.ResetView({
            model: model
            token: token
        }).render().$el.appendTo( $( "#main" ).empty() )
        model.fetch()

    initialize: ( classes ) ->
        @classes = _.extend( {}, module.exports, classes or {} )
        @route( args... ) for args in Router._preroutes

Router._preroutes = []
Router.route = ( args... ) -> @_preroutes.push( args )

# export everything
require( "underscore" ).extend module.exports, { Router: Router },
    views, models