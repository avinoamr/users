fs = require "fs"

_ = require "underscore"
backbone = require "backbone"

user = require "./user.coffee"

$ = backbone.$

# main users list view
html = fs.readFileSync( __dirname + "/../templates/admin.html", encoding: "utf8" )
AdminView = backbone.View.extend
    className: "users container"
    template: _.template( html )
    events:
        "click [data-toggle='users-search']": "show_search"

    show_search: ->
        $.fn.users.search( callback: ( user ) => @collection.add( user ) )

    initialize: ( opts ) ->
        @ItemView = AdminView.ItemView
        @collection.on( "error invalid", @render_error, this )
        @collection.on( "sync error", @render_options, this )
        @collection.on( "add", @render_one, this )
        @collection.on( "add remove reset", @render_count, this )

    render_error: ( c, err ) ->
        err = err.responseText or "Connection Error"
        @$( ".alert" ).html( err ).removeClass( "hide" )

    render_count: ->
        count = "No users"
        if @collection.length == 1
            count = "1 user"
        else if @collection.length > 1
            count = "#{ @collection.length } users"
        @$( "[name='count']" ).html( count )

    render_one: ( m ) ->
        @$( ".panel" ).removeClass( "hide" )
        new @ItemView(
            model: m
        ).render().$el.appendTo( @$( "tbody" ) )
        return this

    can_create: -> @collection.allowed( "POST" )

    render_options: ->
        el = @$( "[data-toggle='users-search']" )
        el.toggleClass( "hide", not @can_create() )

    render: ->
        @$el.html( @template( this ) )
        @render_one( model ) for model in @collection.models
        @render_count()
        @render_options()
        return this

# A single user
html = fs.readFileSync( __dirname + "/../templates/admin.item.html", encoding: "utf8" )
AdminView.ItemView = backbone.View.extend
    tagName: "tr"
    template: _.template( html )
    events:
        "click a[href='#remove']": "destroy"

    destroy: ( ev ) ->
        if ev then ev.preventDefault()
        if confirm( "Are you sure you would like to remove this user?" )
            @model.destroy()

    initialize: ->
        @model.on( "destroy", @remove, this )
        @model.on( "error sync", @render_options, this )

    can_destroy: -> @model.allowed( "DELETE" )
    render_options: ->
        @$( "a[href='#remove']" ).toggleClass( "hide", not @can_destroy() )
        last_login = @model.get( "last_login" )
        if typeof moment != "undefined"
            last_login = moment( last_login ).fromNow()
        @$( "[name='last_login']" ).html( last_login or "Never" )

    render: ->
        @$el.html( @template( this ) )
        uel = new user.View(
            model: @model
            collapsed: false # never allow collapsing in the admin view
        ).render().$el.appendTo( @$( "[name='user']" ) )

        if not @model.get( "verified" )
            uel.addClass( "text-muted" )

        @render_options()

        return this

module.exports = AdminView: AdminView