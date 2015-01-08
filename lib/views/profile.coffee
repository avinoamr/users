fs = require "fs"

_ = require "underscore"
backbone = require "backbone"

user = require "./user.coffee"

$ = backbone.$

html = fs.readFileSync( __dirname + "/../templates/profile.html", encoding: "utf8" )
View = backbone.View.extend
    template: _.template( html )
    className: "users container"
    events:
        "click [name='remove']": ->
            if confirm( "Are you sure you would like to permanently remove this user?" )
                @model.destroy()

        "click [name='edit']": -> @$( "form" ).toggleClass( "hide" )

        "submit form": ( ev ) ->
            ev.preventDefault()
            @$( "form" ).addClass( "hide" )
            @model.save { name: @$( "input[name='name']" ).val() }, { patch: true, wait: true }

    initialize: ->
        @model.on( "destroy", @remove, this )
            .on( "sync", @render, this )
            .on( "sync error", @render_toolbar, this )
            .on  "error", ( m, err ) => @render_message( err.responseText )

    render_message: ( err, msg ) ->
        @$( ".alert" ).html( err or msg )
            .removeClass( "hide" )
            .toggleClass( "alert-danger", not not err )
            .toggleClass( "alert-success", not err )

    render_toolbar: ->
        if @model.allowed( "DELETE" )
            @$( "[name='remove']" ).removeClass( "hide" )
        if @model.allowed( "PATCH" )
            @$( "[name='edit']" ).removeClass( "hide" )

    render: ->
        @$el.html( @template( this ) )
        @render_toolbar()

        if not @model.get( "verified" ) and @model.allowed( "PATCH" )
            @render_message( "You did not verify your email address." )
        return this

module.exports = ProfileView: View
