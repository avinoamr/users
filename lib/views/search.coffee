fs = require "fs"

_ = require "underscore"
backbone = require "backbone"

user = require "./user.coffee"
models = require "../models.coffee"

$ = backbone.$

# search for users
html = fs.readFileSync( __dirname + "/../templates/search.html", encoding: "utf8" )
SearchView = backbone.View.extend
    id: "users-search"
    className: "modal"
    template: _.template( html )
    attributes:
        "tabindex": "-1"
        "role": "dialog"
        "aria-hidden": "true"

    events:
        "shown.bs.modal": ->
            @collection.reset()
            @$( "[name='invite']" ).addClass( "hide" )
            @$( "[name='empty']" ).addClass( "hide" )
            @$( "input" ).val( "" ).first().focus()

        "keyup input[type='text']": ( ev ) ->
            @help( "" )
            if @timeout then clearTimeout( @timeout )
            val = @val()

            if @oldval and @oldval == val then return
            if not val then return @collection.reset()
            @timeout = setTimeout ( =>
                @oldval = val
                @collection.fetch( data: { s: val }, reset: true )
            ), 800

        "submit [name='invite'] form": ( ev ) ->
            ev.preventDefault()
            new @collection.model(
                email: @val(),
                name: $( ev.target ).find( "input[name='name']" ).val()
            ).save {}, success: ( m ) =>
                @trigger( "select:user", model )
                if @opts.callback then @opts.callback( m )
            @$el.modal( "hide" )

    val: -> @$( "input[type='text']" ).val().trim()

    help: ( text ) ->
        err = text == "error"
        @$( ".help-block span" ).toggleClass( "text-danger", err ).html( text )

    initialize: ->
        @collection ?= new models.User.Collection()
        @collection.on( "reset", @render_items, this )
        @collection.on( "error", => @help( "error" ) )
        @collection.on( "request", => @help( "..." ) )
        @collection.on( "sync", => @help( "" ) )

    render: ->
        @$el.html( @template( this ) )
        @render_one( model ) for model in @collection.models
        return this

    render_one: ( model ) ->
        $( "<li><a></a></li>" ).appendTo( @$( "ul" ) )
            .find( "a" )
            .attr( "href", "#" + model.get( "id" ) )
            .append( new user.View( model: model, collapsed: false ).render().$el )
            .on "click", ( ev ) =>
                ev.preventDefault()
                @trigger( "select:user", model )
                if @opts.callback then @opts.callback( model )
                @$el.modal( "hide" )

    render_items: ->
        @$( "ul" ).empty()
        if @collection.length or not @val()
            @$( "[name='invite']" ).addClass( "hide" )
            @$( "[name='empty']" ).addClass( "hide" )
            @render_one( model ) for model in @collection.models
        else @empty()

    empty: ->
        val = @val()
        if models.User.is_valid_email( val )
            name = val.split( "@" )[ 0 ].toLowerCase()
            name = name[ 0 ].toUpperCase() + name.substr( 1 )
            inv = @$( "[name='invite']" ).removeClass( "hide" )
            inv.find( "strong" ).html( val )
            inv.find( "input[name='name']" ).val( name )
            @$( "[name='empty']" ).addClass( "hide" )
        else
            @$( "[name='invite']" ).addClass( "hide" )
            @$( "[name='empty']" ).removeClass( "hide" )

    show: ( opts ) ->
        @opts = opts or {}
        @$el.modal( "show" )
        return this

    toggle: ( opts ) ->
        @opts = opts or {}
        @$el.modal( "toggle" )
        return this

#
SearchView.create = ->
    if not @__instance
        @__instance = new this()
        @__instance.render().$el.appendTo( $( "body" ) )
    return @__instance

$.fn.users ?= {}
$.fn.users.search = ( opts ) -> SearchView.create().toggle( opts )

module.exports = SearchView: SearchView