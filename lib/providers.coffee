events = require "events"
_ = require "underscore"
auth = require "connect-auth"

# a lazy loading wrapper for connect-auth's Strategy instances. By default,
# the strategies must be fully configured upon instantiation, but here we want
# to allow Express configure to manipulate the strategies after they're created
class Provider extends events.EventEmitter
    defaults: {},
    name: null,
    Strategy: null,

    constructor: ( @name, @Strategy, @defaults ) ->
        # authenticate is called with an explicit context, so this will 
        # force the invocation of the authentication of this class instead
        that = this
        @init = false
        @authenticate = ( args... ) ->
            return that._authenticate( this, args... )

    setupRoutes: ( @app ) -> 
        return

    user: -> {}

    _authenticate: ( ctx, req, res, callback ) ->
        port = req.app.get( "port" ) or ""
        if port then port = ":" + port
        host = req.protocol + "://" + req.host + port
        settings = _.extend {}, @defaults, 
            appId: req.app.get( "#{@name}.app_id" ),
            appSecret: req.app.get( "#{@name}.app_secret" ),
            callback: host + req.app.get( "#{@name}.callback" ),

        @emit( "authenticate", settings, req )
        strategy = new @Strategy( settings )
        strategy.name = @name
        strategy.setupRoutes( @app )
        return strategy.authenticate.call ctx, req, res, ( args... ) =>
            if ctx.executionResult and ctx.executionResult.user
                @emit( "authenticated", ctx.executionResult.user )
            callback( args... )

facebook = new Provider( "facebook", auth.Facebook, scope: "email" )
    .on "authenticated", ( user ) ->
        fbid = user.id
        user.picture = "http://graph.facebook.com/#{fbid}/picture?width=16&height=16"

google = new Provider( "google-plus", auth.Google2, requestEmailPermission: true )
    .on "authenticated", ( user ) ->
        user.verified = user.verified_email
        user.picture += "?size=32"

github = new Provider( "github", auth.Github )
    .on "authenticated", ( user ) ->
        user.picture = user.avatar_url + "&size=32"


module.exports.Provider = Provider
module.exports.facebook = facebook
module.exports.google = google
module.exports.github = github