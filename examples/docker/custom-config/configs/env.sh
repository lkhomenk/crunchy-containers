# - Memory -
max_connections = 100
shared_buffers = 512MB
#work_mem = 5242kB
#maintenance_work_mem = 256MB
# - Disk -
temp_file_limit = -1
# - Asynchronous Behavior -
effective_io_concurrency = 200
max_worker_processes = 8
max_parallel_workers_per_gather = 2
max_parallel_workers = 8
#------------------------------------------------------------------------------
# WRITE AHEAD LOG
#------------------------------------------------------------------------------
# - Settings -
wal_level = hot_standby
wal_buffers = 16MB
# - Checkpoints -
checkpoint_timeout = 20min
max_wal_size = 2GB
min_wal_size = 1GB
checkpoint_completion_target = 0.7
#------------------------------------------------------------------------------
# REPLICATION
#------------------------------------------------------------------------------
# - Sending Server(s) -
max_wal_senders = 1
wal_keep_segments = 16
# - Standby Servers -
hot_standby = on
max_standby_archive_delay = 30s
max_standby_streaming_delay = 30s
wal_receiver_status_interval = 10s
# QUERY TUNING
#------------------------------------------------------------------------------
# - Planner Cost Constants -
random_page_cost = 1.1
effective_cache_size = 1024MB
# - Other Planner Options -
default_statistics_target = 100
constraint_exclusion = partition
#------------------------------------------------------------------------------
# ERROR REPORTING AND LOGGING
#------------------------------------------------------------------------------
# - Where to Log -
logging_collector = off
# - What to Log -
log_checkpoints = off
log_connections = off
log_disconnections = off
log_duration = off
log_replication_commands = on
#------------------------------------------------------------------------------
# LOCK MANAGEMENT
#------------------------------------------------------------------------------
max_locks_per_transaction = 512
# - EXTERNAL_CONFIGURATION -
