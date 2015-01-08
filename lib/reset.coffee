crypto = require "crypto"

async = require "async"
_ = require "underscore"
uuid = require "node-uuid"
express = require "express"
mailer = require "nodemailer"

models = require "./models.coffee"

module.exports = -> 

    express()

        # the user has attempted to reset his password
        .put "/:user/reset", ( req, res, next ) ->
            if req.query.token then return next()
            token = uuid.v4() # generate a new reset token
            from = req.app.get( "mail.from" )
            if not from
                throw new Error( "Missing `mail.from` configuration. Can't reset password." )

            # # prepare the reset email
            text = _.template( req.app.get( "users.reset.text" ) or RESET_TEMPLATE_TEXT )
            html = _.template( req.app.get( "users.reset.html" ) or RESET_TEMPLATE_HTML )
            conf = req.app.get( "mail.transport" ) or type: "Direct"
            transport = mailer.createTransport( conf.type, conf );
            message = from: from, subject: "Reset Password"

            async.waterfall [

                # load up the user by its id, email or create a new user
                ( cb ) -> models.User.create( req.params.user, cb )

                # save the reset token to the user details
                ( user, cb ) ->
                    user.save { reset_token: md5( token ) },
                        patch: true,
                        success: -> cb( null, user )

                # send the reset link to the user
                ( user, cb ) ->
                    link = "#{req.protocol}://#{req.get("host")}/#users/#{user.id}/reset/token=#{token}"
                    message.to = user.get( "email" )
                    message.text = text( user: user, link: link )
                    message.html = html( user: user, link: link )
                    transport.sendMail message, ( err ) -> cb( err, user )

            ], ( err, user ) ->
                out = if err then null else id: user.id, email: user.get( "email" )
                res.callback( err, out )

        # the user is trying to update his password using an existing token
        .put "/:user/reset", ( req, res, next ) ->
            if not req.query.token then return next()
            opts = reset_token: true
            async.waterfall [
                ( cb ) -> models.User.create( req.params.user, opts, cb )
                ( user, cb ) ->
                    if not token = user.get( "reset_token" )
                        return cb( "User did not reset his password" )

                    if md5( req.query.token ) != token
                        return cb( "Incorrect reset token" )

                    user.set( password: req.body.password or "" )
                    out = user.validate( user.attributes )
                    if out then return cb( out )

                    # all is well, save the updated user
                    changes =
                        reset_token: null
                        password: md5( req.body.password )
                        verified: true

                    user.once( "invalid error", ( m, err ) -> cb( err ) )
                        .save( changes, patch: true, success: -> cb( null, user ) )

            ], ( err, user ) ->
                out = if err then null else id: user.id
                res.callback( err, out )

md5 = ( str ) -> crypto.createHash( "md5" ).update( str ).digest( "hex" )

RESET_TEMPLATE_TEXT = "
Hello <%=user.title()%>,

You've recently requested to reset the password to your account. Please open the link below to complete your password reset. If you didn't try to reset your password, this may be a malicious attempt to gain access to your account - please contact us and we will investigate it.

<%=link%>
"

RESET_TEMPLATE_HTML = "
<h2>Hello <%=user.title()%>,</h2>

<p>You've recently requested to reset the password to your account. Please open the link below to complete your password reset. If you didn't try to reset your password, this may be a malicious attempt to gain access to your account - please contact us and we will investigate it.</p>

<a href='<%=link%>'><%=link%></a>
"
