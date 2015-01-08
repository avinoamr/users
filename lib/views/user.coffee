backbone = require "backbone"

$ = backbone.$

# user view is a small UI widget to display a user with their avatar, badges,
# links, etc.
View = backbone.View.extend
    tagName: "a"
    className: "user"

    initialize: ( opts ) ->
        @opts = {}
        @collapsed = opts.collapsed
        if typeof @collapsed == "undefined" then @collapsed = null
        @model.on( "sync", @render, this )

    render: ->
        title = $( "<span> " + @model.title() + "</span>" )
            .toggleClass( "hidden-xs", @collapsed == null ) # default, dependent on media-type
            .toggleClass( "hide", @collapsed == true ) # force it to collapse

        img = new Image()
        img.width = 32
        img.height = 32
        img.src = @model.picture()

        @$el.html( img )
            .attr( "href", "#users/#{@model.id}" )
            .attr( "title", @model.title() )
            .css( "text-decoration", "none" )
            .css( "margin-right", "10px;" )
            .append( title )
        return this

module.exports = View: View