# My Postgres is Rusty

This is the accompanying code for the blog post where I fiddle with Rust and Postgres.

## Setup

To execute this code, you must have `cargo` installed. Move the `.env.example` file to `.env` and set the `DATABASE_URL` variable to point to a working Postgres instance. 

If you don't already have sqlx installed:

```bash
cargo install sqlx-cli
```

Then bootstrap the database contents:

```bash
sqlx migrate run
```

## Usage

Running the project code is pretty simple. Yay!

```bash
cargo run
```
