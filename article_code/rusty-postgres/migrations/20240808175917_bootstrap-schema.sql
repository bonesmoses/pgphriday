-- The best and most fun testing table around!

CREATE TABLE sensor_log (
  id            BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  location      VARCHAR NOT NULL,
  reading       BIGINT NOT NULL,
  reading_date  TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_sensor_log_location ON sensor_log (location);
CREATE INDEX idx_sensor_log_reading_date ON sensor_log (reading_date);
