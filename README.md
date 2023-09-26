# make-it-right

Don't look at me I am a messy work in progress.

### TODO

- [ ] Remaining tags definition (thumbnail)
- [ ] Detection of unhandled tags
- [ ] Tag write
- [ ] Serialize
- [ ] Write in place into JPEG (zero previous, write over (must have enough space)
- [ ] Write into JPEG (parse JIF, omit existing, insert)
- [ ] Remove from JPEG
- [ ] Pluto integration

### TODO but only if im given unhealthy amount of coffe

- [ ] Maker Note

### TODO but probablt wont

- [ ] Parse from TIFF (who care)
- [ ] Parse from PNG (barely standard)
- [ ] Parse from HEIC (what is this)
- [ ] Write into and pluto integration for all those file format

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     make-it-right:
       github: your-github-user/make-it-right
   ```

2. Run `shards install`

## Usage

```crystal
require "make-it-right"
```

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/make-it-right/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Pierre Rousselle](https://github.com/your-github-user) - creator and maintainer
