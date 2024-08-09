use dotenvy::dotenv;
use rand::Rng;
use std::env;

use chrono::Local;
use std::thread::sleep;
use std::time::Duration;

use sqlx::postgres::PgPoolOptions;

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
    // Read the environment file and connect using the DATABASE_URL. We will
    // use a pool to reenforce "best practices" for future projects.

    dotenv().expect(".env file not found!");
    let url = env::var("DATABASE_URL").expect("DATABASE_URL not set!");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&url)
        .await
        .expect("Could not connect to Postgres!");

    // Simulate a "logging" where 100 sensors record a single reading. Do this
    // 10 times to simulate a regular sampling. We'll sleep for 1 second, but
    // normally something like this would sample less frequently.

    let mut rng = rand::thread_rng();

    for _ in 1..10 {
        let mut tx = pool.begin().await?;
        println!("Inserting readings for {}", Local::now());

        for i in 1..=100 {
            sqlx::query!(
                "INSERT INTO sensor_log (location, reading, reading_date) 
                 VALUES ($1, $2, $3)",
                &format!("A{i}"),
                rng.gen_range(1..=100),
                Local::now()
            )
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        sleep(Duration::from_secs(1));
    }

    // Examine the rows for a specific location. We can see from the output
    // that the readings are shoved into an anonymous struct, which is
    // actually pretty handy.

    let rows = sqlx::query!(
        "SELECT * 
           FROM sensor_log
          WHERE location = $1
          ORDER BY reading_date",
        "A20"
    )
    .fetch_all(&pool)
    .await?;

    for r in rows {
        println!(
            "Reading #{} at {} on {}: {}",
            r.id, r.location, r.reading_date, r.reading
        );
    }

    Ok(())
}
