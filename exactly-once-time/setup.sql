-- setup for kafkatest / exactly-once-time
--
-- We are using the IOT data as a source.
--
-- sensor_data_fs -> pump -> sensor_data_ns ->

CREATE OR REPLACE SCHEMA "StreamLab_Output_iot";

--  StreamApp start

-- throttle function

CREATE OR REPLACE FUNCTION "StreamLab_Output_iot"."sensor_data_throttlefunc"(inputRows CURSOR, throttleScale int)
    returns TABLE(inputRows.*)
LANGUAGE JAVA
PARAMETER STYLE SYSTEM DEFINED JAVA
NO SQL
EXTERNAL NAME 'class:com.sqlstream.plugin.timesync.ThrottleStream.throttle';

--  ECDA reading adapter/agent with Discovery support

CREATE OR REPLACE FOREIGN STREAM "StreamLab_Output_iot"."sensor_data_fs"
(
    "rt" TIMESTAMP,
    "readings_uuid" VARCHAR(64),
    "recorded_offset" TIMESTAMP,
    "device_key" VARCHAR(32),
    "account_key" VARCHAR(64),
    "signal_strength" INTEGER,
    "model_code" VARCHAR(16),
    "latitude" DOUBLE,
    "longitude" DOUBLE,
    "channel" INTEGER,
    "logged" BOOLEAN,
    "value" REAL,
    "unit" VARCHAR(4),
    "initiated_by" VARCHAR(16),
    "recorded_at" TIMESTAMP,
    "type" VARCHAR(32),
    "sample_count" INTEGER,
    "condition" VARCHAR(8),
    "low_battery" BOOLEAN,
    "probe_connected" BOOLEAN,
    "contact_closure_enabled_and_open" BOOLEAN
)

    SERVER "KAFKA10_SERVER"

OPTIONS (
"PARSER" 'JSON',
        "ROW_PATH" '$',
"rt_PATH" '$.rt',
        "readings_uuid_PATH" '$.readings_uuid',
        "recorded_offset_PATH" '$.recorded_offset',
        "device_key_PATH" '$.device_key',
        "account_key_PATH" '$.account_key',
        "signal_strength_PATH" '$.signal_strength',
        "model_code_PATH" '$.model_code',
        "latitude_PATH" '$.latitude',
        "longitude_PATH" '$.longitude',
        "channel_PATH" '$.sensor_readings[0:].channel',
        "logged_PATH" '$.sensor_readings[0:].logged',
        "value_PATH" '$.sensor_readings[0:].value',
        "unit_PATH" '$.sensor_readings[0:].unit',
        "initiated_by_PATH" '$.sensor_readings[0:].initiated_by',
        "recorded_at_PATH" '$.sensor_readings[0:].recorded_at',
        "type_PATH" '$.sensor_readings[0:].type',
        "sample_count_PATH" '$.sensor_readings[0:].sample_count',
        "condition_PATH" '$.sensor_readings[0:].condition',
        "low_battery_PATH" '$.sensor_readings[0:].low_battery',
        "probe_connected_PATH" '$.sensor_readings[0:].probe_connected',
        "contact_closure_enabled_and_open_PATH" '$.sensor_readings[0:].contact_closure_enabled_and_open',

        "SEED_BROKERS" 'localhost:9092',


        "STARTING_TIME" 'EARLIEST',

        "MAX_POLL_RECORDS" '100',
        "STARTING_OFFSET" '-1',

        "BUFFER_SIZE" '1048576',
        "FETCH_SIZE" '1000000',


        "isolation.level" 'read_uncommitted',
        "TOPIC" 'IoT'

);

CREATE OR REPLACE STREAM "StreamLab_Output_iot"."sensor_data_ns"
(
    "rt" TIMESTAMP,
    "readings_uuid" VARCHAR(64),
    "recorded_offset" TIMESTAMP,
    "device_key" VARCHAR(32),
    "account_key" VARCHAR(64),
    "signal_strength" INTEGER,
    "model_code" VARCHAR(16),
    "latitude" DOUBLE,
    "longitude" DOUBLE,
    "channel" INTEGER,
    "logged" BOOLEAN,
    "value" REAL,
    "unit" VARCHAR(4),
    "initiated_by" VARCHAR(16),
    "recorded_at" TIMESTAMP,
    "type" VARCHAR(32),
    "sample_count" INTEGER,
    "condition" VARCHAR(8),
    "low_battery" BOOLEAN,
    "probe_connected" BOOLEAN,
    "contact_closure_enabled_and_open" BOOLEAN
);

-- pump including throttle - easier for early testing
CREATE OR REPLACE PUMP "StreamLab_Output_iot"."source-to-sensor_data-Pump" STOPPED AS
INSERT INTO "StreamLab_Output_iot"."sensor_data_ns" 
SELECT STREAM * 
FROM STREAM("StreamLab_Output_iot"."sensor_data_throttlefunc" (CURSOR(SELECT STREAM * FROM "StreamLab_Output_iot"."sensor_data_fs"), 1000));

-- pump excluding throttle
--CREATE OR REPLACE PUMP "StreamLab_Output_iot"."source-to-sensor_data-Pump" STOPPED AS
--INSERT INTO "StreamLab_Output_iot"."sensor_data_ns"
--SELECT STREAM *
--FROM "StreamLab_Output_iot"."sensor_data_fs";

CREATE OR REPLACE VIEW "StreamLab_Output_iot"."sensor_data" AS
SELECT STREAM * FROM "StreamLab_Output_iot"."sensor_data_ns";


CREATE OR REPLACE FOREIGN STREAM "StreamLab_Output_iot"."pipeline_2_out_sink_1_fs"
(
    "rt" TIMESTAMP,
    "readings_uuid" VARCHAR(64),
    "recorded_offset" TIMESTAMP,
    "device_key" VARCHAR(32),
    "account_key" VARCHAR(64),
    "signal_strength" INTEGER,
    "model_code" VARCHAR(16),
    "latitude" DOUBLE,
    "longitude" DOUBLE,
    "channel" INTEGER,
    "logged" BOOLEAN,
    "value" REAL,
    "unit" VARCHAR(4),
    "initiated_by" VARCHAR(16),
    "recorded_at" TIMESTAMP,
    "type" VARCHAR(32),
    "sample_count" INTEGER,
    "condition" VARCHAR(8),
    "low_battery" BOOLEAN,
    "probe_connected" BOOLEAN,
    "contact_closure_enabled_and_open" BOOLEAN
)

    SERVER "KAFKA10_SERVER"

OPTIONS (
    "FORMATTER" 'JSON',

        "TRANSACTION_ROWTIME_LIMIT" '1000',
        
        
        "pump.name" 'LOCALDB.StreamLab_Output_iot.pipeline_2_out_sink_1_fs_pump',
        "HA_ROLLOVER_TIMEOUT" '5000',
        "bootstrap.servers" 'localhost:9092',
        "compression.type" 'none',
         "batch.size" '16384',
        "linger.ms" '100',

        
        "retry.backoff.ms" '100',
        "request.timeout.ms" '10000',
        "send.buffer.bytes" '102400',
        
        "POLL_TIMEOUT" '100',
        
        "TOPIC" 'iot_sink'

    );

CREATE OR REPLACE PUMP "StreamLab_Output_iot"."pipeline_2_out_sink_1_fs_pump" STOPPED AS
INSERT INTO "StreamLab_Output_iot"."pipeline_2_out_sink_1_fs" 
SELECT STREAM * FROM "StreamLab_Output_iot"."sensor_data";


