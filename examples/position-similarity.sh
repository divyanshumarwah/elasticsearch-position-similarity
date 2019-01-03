#!/bin/sh

curl --header "Content-Type:application/json" -s -XDELETE "http://localhost:9200/test_index"

curl --header "Content-Type:application/json" -s -XPUT "http://localhost:9200/test_index" -d '
{
  "settings": {
    "index": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "similarity": {
        "default": {
          "type": "classic"
        }
      }
    },
    "similarity": {
      "positionSimilarity": {
        "type": "position-similarity"
      }
    },
    "analysis": {
      "analyzer": {
        "positionPayloadAnalyzer": {
          "type": "custom",
          "tokenizer": "whitespace",
          "filter": [
            "standard",
            "lowercase",
            "asciifolding",
            "positionPayloadFilter"
          ]
        }
      },
      "filter": {
        "positionPayloadFilter": {
          "delimiter": "|",
          "encoding": "int",
          "type": "delimited_payload_filter"
        }
      }
    }
  }
}
'

curl --header "Content-Type:application/json" -XPUT 'localhost:9200/test_index/_mapping/test_type' -d '
{
  "properties": {
    "field1": {
      "type": "text"
    },
    "field2": {
      "type": "text",
      "term_vector": "with_positions_offsets_payloads",
      "analyzer": "positionPayloadAnalyzer",
      "similarity": "positionSimilarity"
    }
  }
}
'

curl --header "Content-Type:application/json" -s -XPUT "localhost:9200/test_index/test_type/1" -d '
{"field1" : "bar foo", "field2" : "bar|0 foo|1"}
'

curl --header "Content-Type:application/json" -s -XPUT "localhost:9200/test_index/test_type/2" -d '
{"field1" : "foo foo bar bar bar", "field2" : "foo|0 foo|1 bar|3 bar|4 bar|5"}
'

curl --header "Content-Type:application/json" -s -XPUT "localhost:9200/test_index/test_type/3" -d '
{"field1" : "bar bar foo foo", "field2" : "bar|0 bar|1 foo|2 foo|3"}
'

curl --header "Content-Type:application/json" -s -XPOST "http://localhost:9200/test_index/_refresh"

echo
echo
echo 'expecting doc 2 to have highest score'

curl --header "Content-Type:application/json" -s "localhost:9200/test_index/test_type/_search?pretty=true" -d '
{
  "explain": false,
  "query": {
    "match": {
      "field2": "foo"
    }
  }
}
'

echo
echo
echo 'explain highest score'

curl --header "Content-Type:application/json" -s "localhost:9200/test_index/test_type/_search?pretty=true" -d '
{
  "explain": true,
  "from": 0,
  "size": 1,
  "query": {
    "match": {
      "field2": "foo"
    }
  }
}
'

echo
echo
echo 'expecting doc 2 to have highest score'

curl --header "Content-Type:application/json" -s "localhost:9200/test_index/test_type/_search?pretty=true" -d '
{
  "explain": false,
  "query": {
    "multi_match": {
      "boost": 3,
      "query": "foo",
      "fields": [
        "field2"
      ]
    }
  }
}
'
