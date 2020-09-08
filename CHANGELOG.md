## 1.2.3 (June 12, 2020)

- Simplifies code in page_caching.rb due to explicit require

  _Xavier Noria_

## 1.2.2 (May 6, 2020)

- Fix variable name

  _Jack McCracken_

## 1.2.1 (May 6, 2020)

- Only write relative URIs when their normalized path begins with the normalized cache directory path

  _Jack McCracken_

## 1.2.0 (December 11, 2019)

- Update Rubocop config

  _Rafael Mendonça França_

- Fix for Rails 6 Mime lookups

  _Rob Zolkos_

- Remove Rails 4.2 from testing matrix

  _Rob Zolkos_

- Minimum of Ruby 2.4 required

  _Rob Zolkos_

- Remove upper dependency for actionpack

  _Anton Kolodii_

## 1.1.1 (September 25, 2018)

- Fixes handling of several forward slashes as root path.

  _Xavier Noria_

- Documentation overhaul.

  _Xavier Noria_

## 1.1.0 (January 23, 2017)

- Support dynamic `page_cache_directory` using a Proc, Symbol or callable

  _Andrew White_

- Support instance level setting of `page_cache_directory`

  _Andrew White_

- Add support for Rails 5.0 and master

  _Andrew White_

## 1.0.2 (November 15, 2013)

- Fix load order problem with other gems.

  _Rafael Mendonça França_

## 1.0.1 (October 24, 2013)

- Add Railtie to set `page_cache_directory` by default to `public` folder.

  Fixes #5.

  _Žiga Vidic_

## 1.0.0 (February 27, 2013)

- Extract Action Pack - Action Caching from Rails core.

  _Francesco Rodriguez_, _Rafael Mendonça França_, _Michiel Sikkes_
