/**
 * Which US state is home to the highest concentration of coffee snobs?
 * Search for coffee snob tweets to answer the question. 
 */
 
-- Parameters - set default values here; you can override with -p on the command-line.
-- Note: uses MORTAR_EMAIL_S3_ESCAPED to put data into a different folder for everyone
%default OUTPUT_PATH 's3n://mortar-example-output-data/$MORTAR_EMAIL_S3_ESCAPED/coffee_tweets'

-- User-Defined Functions (UDFs)
REGISTER '../udfs/python/twitter_places.py' USING streaming_python AS twitter_places;
REGISTER '../udfs/python/coffee.py' USING streaming_python AS coffee;

-- Macros: for shared pig code
IMPORT '../macros/tweets.pig';

-- Load up all of the tweets
-- (to use just a single file, switch to SINGLE_TWEET_FILE())
tweets = ALL_TWEETS();

-- Filter to get only tweets that have a location in the US
tweets_with_place = 
    FILTER tweets 
        BY place IS NOT NULL 
       AND place#'country_code' == 'US' 
       AND place#'place_type' == 'city';

-- Parse out the US state name from the location
-- and determine whether this is a coffee tweet.
coffee_tweets = 
    FOREACH tweets_with_place
   GENERATE text, 
            place#'full_name' AS place_name,
            twitter_places.us_state(place#'full_name') AS us_state,
            coffee.is_coffee_tweet(text) AS is_coffee_tweet;

-- Filter to make sure we only include results with
-- a US State defined
with_state = 
    FILTER coffee_tweets
        BY us_state IS NOT NULL;

-- Group the results by US state
grouped = 
    GROUP with_state 
       BY us_state;

-- Calculate the percentage of coffee tweets
-- for each state
coffee_tweets_by_state = 
    FOREACH grouped
   GENERATE group as us_state,
            100.0 * SUM(with_state.is_coffee_tweet) / COUNT(with_state) AS pct_coffee_tweets;

-- Order by percentage to get the largest
-- coffee snobs at the top
ordered = 
    ORDER coffee_tweets_by_state 
       BY pct_coffee_tweets DESC;

-- Remove any existing output and store the results to S3
rmf $OUTPUT_PATH;
STORE ordered 
 INTO '$OUTPUT_PATH'
USING PigStorage('\t');