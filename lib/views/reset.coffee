fs = require "fs"

_ = require "underscore"
backbone = require "backbone"

user = require "./user.coffee"

html = fs.readFileSync( __dirname + "/../templates/reset.html", encoding: "utf8" )
View = backbone.View.extend
    className: "users container"
    template: _.template( html )
    events:
        "submit form": ( ev ) ->
            ev.preventDefault()
            pass = @$( "[name='password']" ).val()
            passre = @$( "[name='password-repeat']" ).val()
            if pass != passre then return @show_error( "Passwords mismatch" )
            @model.save { password: pass },
                url: @model.url() + "/reset/?token=#{@token}",
                success: => @show_success "Your password was successfully changed"

    initialize: ( opts ) ->
        @token = opts.token
        @model.on( "error invalid", @render_error, this )

    render_message: ( err, msg ) ->
        @$( ".alert" ).html( err or msg )
            .removeClass( "hide" )
            .toggleClass( "alert-danger", not not err )
            .toggleClass( "alert-success", not err )

    show_success: ( msg ) -> @render_message( null, msg )
    show_error: ( msg ) -> @render_message( msg )

    render_error: ( m, err ) ->
        if err.statusText == "Not Found"
            err = "User not found"
        else if err.responseText
            err = err.responseText
        @show_error( err )

    render: ->
        @$el.html( @template( this ) )
        new user.View(
            model: @model
            collapsed: false
        ).render().$el.appendTo( @$( "[name='user']" ).empty() )
        return this

module.exports = ResetView: View