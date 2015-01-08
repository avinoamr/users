express = require "express"
auth = require "connect-auth"
backsync = require "backsync"
allow = require "connect-allow"
users = require "./lib/index"

users.User.prototype.sync = backsync.memory()

express()
    .set( "facebook.app_id", "" )
    .set( "facebook.app_secret", "" )
    .set( "facebook.callback", "/users/auth/facebook_callback" )

    .set( "google-plus.app_id", "" )
    .set( "google-plus.app_secret", "" )
    .set( "google-plus.callback", "/users/oauth2callback" )

    .set( "github.app_id", "" )
    .set( "github.app_secret", "" )
    .set( "github.callback", "/users/auth/github_callback" )

    .set( "mail.from", "" )
    .set( "users.oauth_providers", [ "google-plus", "facebook", "github" ] )

    .set( "port", 8000 )

    .use( express.cookieParser( "adea6a91-9d37-11e3-a5e2-0800200c9a66" ) )
    .use( express.session() )
    .use( express.bodyParser() )
    .use( express.static( __dirname + "/dist" ) )

    .use( "/users", allow( -> true ) )
    .use( "/users", users() )
    .listen( 8000 )