backbone = require "backbone"
blueprint = require "blueprint"

User = blueprint( "User", backbone.Model )
    .define( "urlRoot", "/users" )
    .define "defaults", ->
        verified: false
        email: null
        password: null
        name: null

    .define "parse", ( attrs, options ) ->
        if not options.password and attrs.password
            attrs.password = null
        if not options.reset_token and attrs.reset_token
            attrs.reset_token = null
        return attrs

    .define( "title", -> @get( "name" ) or @get( "email" ) or "" )
    .define( "name", -> @title().split( "@" )[ 0 ] )
    .define( "first_name", -> @name().split( " " )[ 0 ] )
    .define( "allowed", ( action ) -> action in @meta( "Allow" ).split( "," ) )
    .define( "meta", ( key ) -> if @_xhr and o = @_xhr.getResponseHeader( key ) then o else "" )

    .define "initialize", ->
        @_xhr = null
        @on "sync error add", ( c, m, opts ) =>
            # add is here to allow collection fetches to also set the allowed
            # keywords
            if opts and opts.xhr then @_xhr = opts.xhr # saves the last xhr

    .define "picture", ( size ) ->
        size ?= 32
        if @has( "picture" ) then return @get( "picture" )
        else return "http://www.gravatar.com/avatar/#{@id}/?s=" + size

    .define "validate", ( attrs ) ->
        if not attrs.email
            return "Email and Password are required"
        if not User.is_valid_email( attrs.email )
            return "Invalid email address"
        if attrs.password != null and attrs.password.length < 6
            return "Password must have at least 6 characters"
        return null

    .define "default", ( attrs ) ->
        for attr, value of attrs
            if not @get( attr ) then @set( attr, value )
        return this

    .define "reset_password", ( email, opts ) ->
        opts ?= {}
        opts.url = @urlRoot + "/#{email}/reset"
        @sync "update", this, opts

    .define "login", ( email, password, options ) ->
        options ?= {}
        error = options.error
        success = options.success

        options.wait ?= true
        options.url ?= "/users/login/"
        options.error = =>
            # if @id then @set( "id", null ).trigger( "logout", this )
            if error then error.apply( this, arguments )

        options.success = =>
            @trigger( "login", this )
            if @reload then window.location.reload()
            if success then success.apply( this, arguments )

        this.save({ email: email, password: password }, options )

    .define "logout", ->
        @fetch({
            url: "/users/logout/",
            success: =>
                @trigger( "logout" )
        });
        return this

    .create()

EMAIL_RE = /^([0-9a-zA-Z]([-\.\w]*[0-9a-zA-Z])*@([0-9a-zA-Z][-\w]*[0-9a-zA-Z]\.)+[a-zA-Z]{2,9})$/
User.is_valid_email = ( email ) ->
    # optimization, while matching the regexp alone will suffice, this regexp match
    # can be extremely slow for some non-email strings (like md5 strings)
    email.indexOf( "@" ) != -1 and email.indexOf( "." ) != -1 and email.match( EMAIL_RE )

# returns an existing user by its id/email, or create a new one by email
User.create = ( id, opts, cb ) ->
    if not cb and typeof opts == "function"
        cb = opts
        opts = {}

    opts.error = ( c, err ) -> cb( err )
    if User.is_valid_email( id )
        opts.success = ( c ) ->
            user = c.models[ 0 ] or new User()
            cb( null, user.set( email: id ) )
        opts.data = { email: id }
        new User.Collection().fetch( opts )
    else
        opts.success = ( m ) -> cb( null, m )
        new User( id: id ).fetch( opts )


User.self = new User( id: "self" )

User.Collection = backbone.Collection.extend
    model: User
    url: -> @model.prototype.urlRoot
    sync: -> @model.prototype.sync.apply( this, arguments )
    meta: -> @model.prototype.meta.apply( this, arguments )
    allowed: -> @model.prototype.allowed.apply( this, arguments )
    initialize: ->
        @_xhr = null
        @on "sync error", ( c, m, opts ) =>
            if opts and opts.xhr then @_xhr = opts.xhr


module.exports = User: User