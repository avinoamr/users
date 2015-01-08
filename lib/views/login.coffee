fs = require "fs"

_ = require "underscore"
backbone = require "backbone"

models = require "../models.coffee"
user = require "./user.coffee"

$ = backbone.$

html = fs.readFileSync( __dirname + "/../templates/login.html", encoding: "utf8" )
LoginView = backbone.View.extend
    template: _.template( html )
    events:
        "click [href='#login']": ( ev ) ->
            ev.preventDefault()
            @toggle() # show the login modal

        "click a[href='#switch']": ( ev ) ->
            ev.preventDefault()
            @logout()
            @toggle()

    logout: -> 
        @model.fetch({
            url: "/users/logout/",
            success: =>
                @model.trigger( "logout" )
                @trigger( "logout", @model )
        });

    initialize: ( opts ) ->
        # default to the current user, and attempt to fetch it
        opts ?= {}
        if not opts.model
            @model = models.User.self
            @model.fetch()
        @on( "login logout", @render_user, this )
        @model.on "change:id", =>
            ev = if @model.id == "self" then "login" else "logout"
            @trigger( ev, this, @model )

    render_user: ->
        if @model.id != "self"
            @$( "[data-toggle='dropdown']" )
                .empty()
                .removeClass( "hide" )
                .append( new user.View( model: @model ).render().$el )
            @$( "[href='#login']" ).addClass( "hide" )
        else
            @$( "[data-toggle='dropdown']" ).addClass( "hide" )
            @$( "[href='#login']" ).removeClass( "hide" )
        return this

    render: ->
        @$el.html( @template( this ) )
        @render_user()

        $( window ).on "hashchange", =>
            if window.location.hash == "#login" then return
            @hide()
        return this

    toggle: ->
        if not @dialog
            @dialog = new LoginView.Dialog( model: @model ).render()

        @dialog.toggle()
        return this

    hide: -> if @dialog then @dialog.hide()
    show: -> if @dialog then @dialog.show()



html = fs.readFileSync( __dirname + "/../templates/login-dialog.html", encoding: "utf8" )
LoginView.Dialog = backbone.View.extend
    template: _.template( html )
    className: "modal"
    attributes:
        "tabindex": "-1"
        "role": "dialog"
        "aria-hidden": "true"

    events:
        "click a[href='#forgot']": ( ev ) ->
            ev.preventDefault()
            email = @$( "[name='email']" ).val()
            if not email or not models.User.is_valid_email( email )
                @show_error( "Please enter a valid email address" )
            @model.reset_password email,
                error: ( m, err ) => @render_message( err.responseText )
                success: ( res ) =>
                    @render_message( null, "The password reset " +
                            "instructions were sent to <b>#{res.email}</b>" )

        "click button[href^='/users/login/']": ( ev ) ->
            ev.preventDefault()
            target = $( ev.currentTarget )
            href = ( Backbone.host or "" ) + target.attr( "href" )
            w = window.open( href, "_blank", "location=no" ) 
            w.addEventListener "loadstop", => # for cordova InAppBrowser plugin
                w.executeScript { code: "window.User" }, ( results ) =>
                    if results and results.length and results.length > 0
                        user = results[ 0 ]
                        if user then window.users_login( user )

            window.users_login = ( user ) =>
                delete window.users_login
                w.close()
                @model.set( user ).trigger( "login" )
                @trigger( "login", @model )
                if @reload then window.location.reload()
            return href

        "submit form": ( ev ) ->
            ev.preventDefault()
            target = $( ev.target )
            email = target.find( "[type='email']" ).val()
            password = target.find( "[type='password']" ).val()
            @login( email, password )

    initialize: ( options ) ->
        @listenTo( @model, "sync error", @render_options )
        @listenTo( @model, "error", ( m, err ) -> @show_error( err ) )
        @listenTo @model, "login", -> 
            @trigger( "login" )
            if @reload then window.location.reload()
        @reload = if options.reload == false then false else true

    render_message: ( err, msg ) ->
        @$( ".alert" ).html( err or msg )
            .removeClass( "hide" )
            .toggleClass( "alert-danger", not not err )
            .toggleClass( "alert-success", not err )

    show_message: ( msg ) -> @render_message( null, msg )
    show_error: ( msg ) -> @render_message( msg )

    render_options: ->
        links = @$( "[name='providers']" ).empty()
        providers = @model.meta( "X-OAuth-Providers" ).split( "," )
        for provider in providers
            link = "/users/login/#{provider}/"
            title = provider[ 0 ].toUpperCase() + provider.substr( 1 )
            title = "Sign in with #{title}"
            $( "<button href='#{link}' title='#{title}' target='_blank'>" )
                .addClass( "btn btn-dark fa fa-" + provider )
                .appendTo( links )
        return this

    login: ( email, password ) ->
        @model.login( email, password );

    render: ->
        @$el.html( @template( this ) )
        @render_options()
        $( "body" ).append( @$el )
        return this

    toggle: -> @$el.modal( "toggle" )
    hide: -> @$el.modal( "hide" )
    show: -> @$el.modal( "show" )


module.exports = LoginView: LoginView
