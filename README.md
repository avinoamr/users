users
=====

A users management system in Node.js

### Install

```
$ npm install git+https://github.com/avinoamr/users --save
```

### Server

See server.js for a running example.

```javascript
var express = require( "express" );
var session = require( "express-session" );
var allow = require( "connect-allow" );
var backsync = require( "backsync" );
var users = require( "users" );

// this module uses Backbone Models
// define a sync method (or use backsync) to implement
// the actual persistence layer
// see: https://github.com/avinoamr/backsync
users.User.prototype.sync = backsync.memory();

express()

  // ... add additional settings
  .set( "users.oauth_providers", [ "google-plus" ] )
  
  .set( "google-plus.app_id", "<APP_ID>>" )
  .set( "google-plus.app_secret", "<<SECRET>>" )
  .set( "google-plus.callback", "http://127.0.0.1:8000/users/oauth2callback" )
  
  // expose the client static code
  .use( "/users", express.static( "node_modules/users/dist/" ) )
  
  // by default, access to the users console is limited,
  // use connect-allow to implement your own logic here
  // see: https://github.com/avinoamr/connect-allow
  .use( allow( function () { return true } ) )
  
  // a session is required
  .use( session( { secret: "<SESSION_SECRET>" } ) )
  
  // and finally, route to the middleware itself
  .use( "/users", users() )
  .listen( 8000 );
```
