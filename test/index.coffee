crypto = require "crypto"
assert = require "assert"

_ = require "underscore"
mailer = require "nodemailer"
backsync = require "backsync"

models = require "../lib/models"
users = require ".."

models.User.prototype.sync = backsync.memory( ds = {} )

describe "index", ->

    it "sets the X-OAuth-Providers header", ( done ) ->
        app = users().set( "users.oauth_providers", [ "google", "facebook" ] )
        req = url: "/test"
        res = mkres()
        next = ->
            assert.equal( res.headers[ "X-OAuth-Providers" ], "google,facebook" )
            done()
        app( req, res, next )


    it "sets the user in the session with connect-auth", ( done ) ->
        req = url: "/test", session: auth: user: id: 123
        res = mkres()
        next = ->
            assert.equal( req.getAuthDetails().user.id, 123 )
            done()
        users()( req, res, next )

    it "fails /self if the user is not logged in", ( done ) ->
        req = url: "/self", method: "GET"
        res = mkres send: ( code ) ->
            assert.equal( code, 404 )
            done()
        users()( req, res )


    it "redirects /self if the user is logged in", ( done ) ->
        req = url: "/self", method: "GET", session: auth: user: id: 123
        res = mkres redirect: ( path ) ->
            assert.equal( path, "/123" )
            done()
        users()( req, res )


describe "login", ->
    tmp = {}

    before ->
        tmp.validate = models.User.prototype.validate
        models.User.prototype.validate = -> null

    after -> models.User.prototype.validate = tmp.validate
    beforeEach -> ds[ "/users" ] = {}

    it "logs out", ( done ) ->
        req = url: "/logout", headers: { accept: "text/html" }, session: auth: user: id: 123
        res = mkres redirect: ( path ) ->
            assert( not req.getAuthDetails().user ) # user doesn't exist
            assert.equal( path, "/" )
            done()
        users()( req, res )


    it "logs out but returns an empty object in XHR", ( done ) ->
        req = url: "/logout", xhr: true, session: auth: user: id: 123
        res = mkres send: ( obj ) ->
            assert( not req.getAuthDetails().user ) # used doesn't exist
            assert.deepEqual( obj, {} )
            done()
        users()( req, res )


    it "validates the model", ( done ) ->
        validate = models.User.prototype.validate
        models.User.prototype.validate = ( attrs ) ->
            assert.equal( attrs.email, "email" )
            assert.equal( attrs.password, "" ) # null -> empty string
            return "break it"
        req =   url: "/login", body: { email: "email", password: null }
        res = mkres callback: ( err ) ->
            assert.equal( err, "break it" )
            models.User.prototype.validate = validate # restore
            done()
        users()( req, res )


    it "creates a new user", ( done ) ->
        req =  url: "/login", xhr: true, body: { email: "email", password: "123456" }
        res = mkres callback: ( err, res, u ) ->
            assert.equal( err, null )
            assert( res.id ) # user id exists
            user = req.getAuthDetails().user
            assert.equal( user.email, "email" )

            # doesn't save the real password, but the hashed one
            assert.equal( user.password, md5( "123456" ) )
            done()
        users()( req, res )


    it "succeeds with the correct password", ( done ) ->
        ds[ "/users" ][ "123" ] =
            email: "email"
            password: md5( "123456" )
            id: "123"
        req =  url: "/login", xhr: true, body: { email: "email", password: "123456" }
        res = mkres callback: ( err, res ) ->
            assert.equal( err, null )
            assert.equal( res.id, "123" )
            user = req.getAuthDetails().user
            assert( "_id" not in Object.keys( user ) ) # empty provider name shouldn't create the id
            last_login = user.last_login.getTime()
            assert( t <= last_login <= ( new Date().getTime() ) ) # sets the login date
            done()
        t = new Date().getTime()
        users()( req, res )


    it "fails with the wrong password", ( done ) ->
        ds[ "/users" ][ "123" ] =
            email: "email"
            password: md5( "123456x" )
            id: "123"
        req =  url: "/login", xhr: true, body: { email: "email", password: "123456" }
        res = mkres callback: ( err, res ) ->
            assert.equal( err, "Incorrect Password" )
            done()
        users()( req, res )


    it "doesn't authenticates with the failed provider", ( done ) ->
        req =  url: "/login/test", headers: {}
        res = mkres callback: ( err, res ) ->
            assert.equal( err.name, "ForbiddenError" )
            done()

        test_provider = mkprovider -> @fail( arguments[ 2 ] )
        users( [ test_provider ] )( req, res )


    it "extends the user data with the authenticated provider", ( done ) ->
        req =  url: "/login/test", xhr: true, headers: {}
        res = mkres callback: ( err, res ) ->
            assert( res.id )
            user = req.getAuthDetails().user
            assert.deepEqual( user, ds["/users" ][ user.id ] ) # actually saved
            assert.equal( user.id, res.id )
            assert.equal( user.name, "Test" )
            assert.equal( user.test_id, 15 ) # saves the provider id
            assert.equal( user.verified, true )
            assert.equal( user.password, null ) # remains null
            assert.equal( user.email, "email" ) # remains null
            assert( not user.something ) # doesn't safe everything
            done()

        test_provider = mkprovider ->
            @success({
                name: "Test",
                something: "else",
                id: 15,
                verified: true
                email: "email"
            }, arguments[ 2 ] )
        users( [ test_provider ] )( req, res )


describe "reset", ->
    tmp = {}
    before ->
        tmp.createTransport = mailer.createTransport
        mailer.createTransport = ( type, args ) ->
            tmp.transport = type: type, args: args, sendMail: ( message, cb ) ->
                @message = message
                cb()

    after -> mailer.createTransport = tmp.createTransport


    it "throws an error on misconfiguration", ( done ) ->
        req =  url: "/123/reset", headers: {}, method: "PUT"
        res = mkres()
        users() req, res, ( err ) ->
            assert( err )
            assert( err.message.indexOf( "mail.from" ) != -1 )
            done()


    it "fails for non-existing users", ( done ) ->
        req =  url: "/123/reset", headers: {}, method: "PUT"
        res = mkres callback: ( err ) ->
            assert.equal( err.name, "NotFoundError" )
            done()
        users().set( "mail.from", "test" )( req, res )


    it "sends the email with the correct reset token", ( done ) ->
        req =  url: "/test@gmail.com/reset", headers: {}, method: "PUT", connection: {}
        res = mkres callback: ( err, res ) ->
            assert( not err )
            assert.equal( tmp.transport.type, "Direct" ) # default
            assert.equal( tmp.transport.message.from, "test" )
            assert.equal( tmp.transport.message.to, "test@gmail.com" )
            assert.equal( res.email, "test@gmail.com" )
            assert( tmp.transport.message.subject ) # not empty subject
            html = tmp.transport.message.html

            href = html.match( /href\=\'.*\/(.*)\/reset\/token\=(.*)\'/ )
            user = href[ 1 ]
            token = href[ 2 ]

            assert.equal( user, res.id ) # user id is correct
            user = ds[ "/users" ][ user ]
            assert.equal( res.email, user.email ) # correct email
            assert.equal( md5( token ), user.reset_token ) # correct md5 token
            done()
        users().set( "mail.from", "test" )( req, res )


    it "fails if the user didn't reset his password", ( done ) ->
        ds[ "/users" ][ "123" ] = {}
        req =  url: "/123/reset?token=abc", headers: {}, method: "PUT", connection: {}
        res = mkres callback: ( err, res ) ->
            assert.notEqual( err.toString().indexOf( "did not reset" ), -1 )
            done()
        users()( req, res )


    it "fails if the reset token is incorrect", ( done ) ->
        ds[ "/users" ][ "123" ] = reset_token: "abc" # not md5'd
        req =  url: "/123/reset?token=abc", headers: {}, method: "PUT", connection: {}
        res = mkres callback: ( err, res ) ->
            assert.notEqual( err.toString().indexOf( "Incorrect" ), -1 )
            done()
        users()( req, res )


    it "fails if the new passowrd is invalid", ( done ) ->
        validate = models.User.prototype.validate
        models.User.prototype.validate = -> return "break"
        ds[ "/users" ][ "123" ] = reset_token: md5( "abc" )
        req =  url: "/123/reset?token=abc", headers: {}, method: "PUT", connection: {}, body: {}
        res = mkres callback: ( err, res ) ->
            assert( err.toString(), "break" )
            models.User.prototype.validate = validate
            done()
        users()( req, res )


    it "changes the user password", ( done ) ->
        validate = models.User.prototype.validate
        models.User.prototype.validate = -> null
        ds[ "/users" ][ "123" ] = reset_token: md5( "abc" )
        req =
            url: "/123/reset?token=abc",
            headers: {},
            method: "PUT",
            connection: {},
            body: { password: "newpass" }

        res = mkres callback: ( err, res ) ->
            assert( not err )
            assert( res.id, "123" )
            user = ds[ "/users" ][ "123" ]
            assert( not user.reset_token ) # removed
            assert.equal( user.password, md5( "newpass" ) )
            assert.equal( user.verified, true )
            models.User.prototype.validate = validate
            done()
        users()( req, res )


describe "API", ->

    beforeEach -> ds[ "/users" ] = {}

    it "GET list of users", ( done ) ->
        ds[ "/users" ][ "123" ] = { email: "test", password: "123", reset_token: "456" }
        req = url: "/", method: "GET", allowed: -> true
        res = mkres write: ( out ) ->
            assert.equal( this.statusCode, 200 )
            out = JSON.parse( out )
            assert.equal( out.length, 1 )
            assert.equal( out[ 0 ].email, "test" )
            assert( not out[ 0 ].password ) # do not expose the password
            assert( not out[ 0 ].reset_token ) # do not expose the token
            done()
        users() req, res, ( err ) ->
            process.nextTick -> assert.fail( err.toString(), null )


    it "fails to GET list of users if not allowed", ( done ) ->
        req = url: "/", method: "GET", allowed: ( u, m ) -> m != "GET"
        res = mkres write: ( out ) ->
            assert.equal( this.statusCode, 405 )
            assert.equal( out, "Not Allowed" )
            done()
        users() req, res, ( err ) ->
            process.nextTick -> assert.fail( err.toString(), null )


    it "GET search for users", ( done ) ->
        ds[ "/users" ] =
            123: { email: "test", name: "Alice" }
            456: { email: "test", name: "Bob" }

        req = url: "/?s=b", method: "GET", allowed: -> true
        res = mkres write: ( out ) ->
            assert.equal( this.statusCode, 200 )
            out = JSON.parse( out )
            assert.equal( out.length, 1 ) # just bob
            assert.equal( out[ 0 ].name, "Bob" )
            done()
        users() req, res, ( err ) ->
            process.nextTick -> assert.fail( err.toString(), null )


    it "has a limit on searches", ( done ) ->
        opts = {}
        sync = models.User.Collection.prototype.sync
        models.User.Collection.prototype.sync = ( method, c, opts ) ->
            models.User.Collection.prototype.sync = sync
            assert( opts.data.$limit )
            done()

        req = url: "/?s=a", method: "GET", allowed: -> true
        res = mkres()
        users() req, res, ( err ) ->
            process.nextTick -> assert.fail( err.toString(), null )


    it "GET a specific user", ( done ) ->
        ds[ "/users" ][ "123" ] = { email: "test", password: "123", reset_token: "456" }
        req = url: "/123", method: "GET", allowed: -> true
        res = mkres write: ( out ) ->
            assert.equal( this.statusCode, 200 )
            out = JSON.parse( out )
            assert.equal( out.email, "test" )
            done()
        users() req, res, ( err ) ->
            process.nextTick -> assert.fail( err.toString(), null )


    it "fails to GET a specific user when it doesn't exist", ( done ) ->
        req = url: "/123", method: "GET", allowed: -> true
        res = mkres write: ( out ) ->
            assert.equal( this.statusCode, 404 )
            assert.equal( out, "Not Found" )
            done()
        users() req, res, ( err ) ->
            process.nextTick -> assert.fail( err.toString(), null )


    it "creates a new user", ( done ) ->
        validate = models.User.prototype.validate
        models.User.prototype.validate = -> null
        allowed = null
        req =
            url: "/", method: "POST", allowed: -> true
            body: { name: "A", email: "B", password: "C" }

        res = mkres write: ( out ) ->
            assert.equal( this.statusCode, 200 )
            out = JSON.parse( out )
            assert.equal( out.name, "A" )
            assert.equal( out.email, "B" )
            assert.equal( out.id, md5( "B" ) ) # the id is the md5 of the email
            assert( not out.password ) # not-editable
            models.User.prototype.validate = validate
            done()
        users() req, res, ( err ) ->
            process.nextTick -> assert.fail( err.toString(), null )


    it "updates an existing user", ( done ) ->
        ds[ "/users" ][ "123" ] = email: "hello", password: "world", name: "C"
        validate = models.User.prototype.validate
        models.User.prototype.validate = -> null
        allowed = null
        req =
            url: "/123", method: "PATCH", allowed: -> true
            body: { name: "A", email: "B" }
        res = mkres write: ( out ) ->
            assert.equal( this.statusCode, 200 )
            out = JSON.parse( out )
            assert.equal( out.id, "123" )
            assert.equal( out.name, "A" )
            assert.equal( ds[ "/users" ][ "123" ].name, "A" )
            assert.equal( out.email, "hello" ) # unchanged!
            models.User.prototype.validate = validate
            done()
        users() req, res, ( err ) ->
            process.nextTick -> assert.fail( err.toString(), null )


    it "removes an existing user", ( done ) ->
        ds[ "/users" ][ "123" ] = email: "hello", password: "world"
        allowed = null
        req =
            url: "/123", method: "DELETE", allowed: ( ( u, m ) -> ( allowed = m ) and true )
        res = mkres write: ->
            assert.equal( this.statusCode, 200 )
            assert( not ds[ "/users" ][ "123" ] )
            assert.equal( allowed, "DELETE" )
            done()
        users() req, res, ( err ) ->
            process.nextTick -> assert.fail( err.toString(), null )



mkprovider = ( opts ) ->
    opts ?= {}
    if typeof opts == "function" then opts = { authenticate: opts }
    _.defaults opts or { authenticate: ( rq, rs, next ) -> },
        name: "test",
        setupRoutes: -> null
        authenticate: ( req, res, next ) -> @fail( next )

mkres = ( opts ) -> _.defaults opts or {},
    headers: {},
    end: ->
    setHeader: ( k, v ) -> @headers[ k ] = v
    allow: ->

md5 = ( str ) -> crypto.createHash( "md5" ).update( str ).digest( "hex" )