crypto = require "crypto"

_ = require "underscore"
auth = require "connect-auth"
express = require "express"
connect_callback = require "connect-callback"
connect_backbone = require "connect-backbone"
connect_allow = require "connect-allow"

models = require "./models"
providers = require "./providers"

module.exports = ( providers ) -> 
    express()
        .use( connect_callback() )
        .use( auth( providers or _.values( module.exports.providers ) ) )
        .use ( req, res, next ) ->
            # notify the client of all available oauth providers
            providers = req.app.get( "users.oauth_providers" ) or []
            res.set( "X-OAuth-Providers", providers.join( "," ) )
            next()

        .use( require( "./login" )() )
        .use( require( "./reset" )() )

        # redirect self to the id of the current logged in user
        .use "/self", ( req, res, next ) ->
            if not req.getAuthDetails().user
                return res.send( 404 )
            path = req.originalUrl.replace( "self", req.getAuthDetails().user.id )
            res.redirect( path )

        # REST API
        .use( connect_backbone( models.User.Collection ) )
        .use( connect_allow() )
        .patch "/:id", ( req, res, next ) ->
            delete req.body.email
            delete req.body.password
            next()

        .post "/", ( req, res, next ) ->
            req.body.id = md5( req.body.email )
            delete req.body.password
            next()

        .delete( "/:id", ( req ) -> req.model.destroy( res: true ) )
        .patch(  "/:id", ( req ) -> req.model.save( req.body, patch: true, res: true ) )
        .get(    "/:id", ( req ) -> req.model.fetch( res: true ) )
        .post(   "/",    ( req ) -> req.model.save( req.body, res: true ) )
        .get     "/",    ( req, res, next ) ->
            query = req.query
            if query.q
                _.extend( query, JSON.parse( query.q ) )
                delete query.q

            delete query.password
            delete query.reset_token
            if query.s
                re = new RegExp( "^#{query.s}", "i" )
                delete query.s
                query[ "$or" ] = [ { name: re }, { email: re } ]
            query[ "$limit" ] = 100
            req.collection.fetch( data: query, res: true )

module.exports.providers = providers
_.extend( module.exports, models )

md5 = ( str ) -> crypto.createHash( "md5" ).update( str ).digest( "hex" )
