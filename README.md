Xray-rails
==========

Forked from [xray-rails](https://github.com/brentd/xray-rails)

### changes from main repo:
* drop support for .jst
* always inject xray.js and its friends regardless of jquery is included or not


## Usage

Xray depends on **jQuery**. Please make sure Jquery is loaded

This gem should only be present during development. Add it to your Gemfile:

```ruby
group :development do
  gem 'xray-rails'
end
```

Then bundle and delete your cached assets:

```
$ bundle && rm -rf tmp/cache/assets
```

Restart your app, visit it in your browser, and press **cmd+shift+x** (Mac) or **ctrl+shift+x** to reveal the overlay.

#### Note about `config.assets.debug`

Xray will insert itself into your views automatically only if `config.assets.debug = true` (Rails' default)

## Configuration

By default, Xray will check a few environment variables to determine
which editor to open files in: `$GEM_EDITOR`, `$VISUAL`, then
`$EDITOR` before falling back to `/usr/local/bin/subl`.

You can configure your editor of choice either by setting one of these
variables, or in Xray's UI, or in an `~/.xrayconfig` YAML file:

```yaml
:editor: '/usr/local/bin/mate'
```

For something more complex, use the `$file` placeholder.

```yaml
:editor: "/usr/local/bin/tmux new-window 'vim $file'"
```

## How this works

* At run time, HTML responses from Rails are wrapped with HTML comments containing filepath info.
* A middleware inserts `xray.js`, `xray.css`, and the Xray bar into all successful HTML response bodies.
* When the overlay is shown, `xray.js` examines the inserted filepath info to build the overlay.

