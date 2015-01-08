url = require "url"
crypto = require "crypto"

async = require "async"
_ = require "underscore"
uuid = require "node-uuid"
express = require "express"
mailer = require "nodemailer"
blueprint = require "blueprint"

models = require "./models"
module.exports = -> 

    express()

        # logout
        .use "/logout", ( req, res ) ->
            req.logout()
            if req.xhr or req.accepts( "json" )
                res.send({})
            else res.redirect( "/" )

        # login
        .use "/login", ( req, res, next ) ->
            password_md5 = null
            password = null
            email = null
            provider = url.parse( req.url ).pathname.replace( /\//g, "" )
            if not provider
                password = req.body.password or ""
                email = req.body.email
                out = new models.User().validate( email: email, password: password )
                if out then return res.callback( out )
                password_md5 = md5( password )

            async.waterfall [

                # start by authenticating the user against the selected provider
                ( cb ) ->
                    if not provider then return cb( null, email: email )
                    req.authenticate provider, ( err, authenticated ) ->

                        # undefined means that the response has been
                        # redirected. nothing left to do here.
                        if typeof authenticated == "undefined" then return
                        else if authenticated == false
                            return cb( { name: "ForbiddenError" } )
                        cb( null, req.getAuthDetails().user )

                # lookup for the user or create a new one
                ( details, cb ) ->
                    new models.User.Collection()
                        .once( "error invalid", ( m, err ) -> cb( err ) )
                        .fetch
                            data: { email: details.email },
                            password: true,
                            success: ( m ) -> cb( null, m, details )

                # validate the user password and update the user
                ( collection, details, cb ) ->
                    attrs = last_login: new Date()
                    user = collection.models[ 0 ]

                    # user not found, create one.
                    patch = true
                    if not user
                        patch = false
                        attrs.password = password_md5
                        attrs.email = details.email
                        user = new models.User( id: md5( attrs.email ) ).set( attrs )

                    upass = user.get( "password" )
                    if provider
                        attrs[ "#{provider}_id" ] = details.id
                    else if upass != password and upass != password_md5
                        return cb( "Incorrect Password" )

                    details = _.pick( details, [ "name", "picture", "verified" ] )
                    for key, value of details
                        if not user.get( key ) then attrs[ key ] = value

                    # console.log( attrs )
                    user.once( "error invalid", ( m, err ) -> cb( err ) )
                        .save( attrs, { 
                            patch: patch, 
                            password: true,
                            success: -> cb( null, user ) 
                        })

            ], ( err, user  ) ->
                if err then return res.callback( err )
                user = req.getAuthDetails().user = user.toJSON()
                next = req.query.next
                if provider and not req.xhr
                    user = JSON.stringify( user )
                    res.callback( null, CLOSE_HTML.replace( "{{USER}}", user ) )
                else if next and not req.xhr
                    res.redirect( req.query.next )
                else
                    return res.callback( null, user )


CLOSE_HTML = "
<html>
<body>
    <script>
    window.User={{USER}};
    if ( window.opener && window.opener.users_login )
        window.opener.users_login( window.User );
    </script>
</body>
</html>"

VERIFY_TEMPLATE_TEXT = "
Hello <%=user.title()%>, and welcome!

Please open the link below to verify your email address:

<%=link%>
"

VERIFY_TEMPLATE_HTML = "
<h2>Hello <%=user.title()%>, and welcome!</h2>

<p>Please open the link below to verify your email address:</p>

<a href='<%=link%>'><%=link%></a>
"

md5 = ( str ) -> crypto.createHash( "md5" ).update( str ).digest( "hex" )
