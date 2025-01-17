package com.example.datamart;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hazelcast.map.IMap;
import com.mongodb.client.MongoCollection;
import org.bson.Document;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class DataMart {
    private final MongoDBConnection mongoConnection;
    private final HazelcastConnection hazelcastConnection;
    private final ObjectMapper objectMapper = new ObjectMapper(); 

    public DataMart(MongoDBConnection mongoConnection, HazelcastConnection hazelcastConnection) {
        this.mongoConnection = mongoConnection;
        this.hazelcastConnection = hazelcastConnection;
    }

    public void buildDataMart() {
        System.out.println("Building the DataMart...");

        MongoCollection<Document> wordsCollection = mongoConnection.getCollection("words");
        MongoCollection<Document> usageCollection = mongoConnection.getCollection("word_usage");

        IMap<String, String> wordsMap = hazelcastConnection.getWordsMap(); 
        IMap<String, String> graphMap = hazelcastConnection.getGraphMap(); 

        ExecutorService executor = Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors());

        for (Document word : wordsCollection.find()) {
            executor.submit(() -> {
                try {
                    String wordText = word.getString("word");
                    Object wordId = word.getObjectId("_id");

                    List<Map<String, Object>> usages = loadWordUsages(wordId, usageCollection);
                    String usagesJson = objectMapper.writeValueAsString(usages);

                    wordsMap.put(wordText, usagesJson);
                    System.out.println("Added word to words_map: " + wordText + " with usages: " + usagesJson);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });
        }

        executor.shutdown();
        while (!executor.isTerminated()) {}

        executor = Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors());

        Set<String> allWords = wordsMap.keySet();
        for (String word : allWords) {
            executor.submit(() -> {
                try {
                    List<String> connectedWords = findConnectedWords(word, allWords);
                    String connectedWordsJson = objectMapper.writeValueAsString(connectedWords);

                    graphMap.put(word, connectedWordsJson);
                    System.out.println("Processed word '" + word + "' with connected words: " + connectedWordsJson);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });
        }

        executor.shutdown();
        while (!executor.isTerminated()) {}

        System.out.println("DataMart built successfully.");
    }

    private List<String> findConnectedWords(String word, Set<String> allWords) {
        return allWords.parallelStream()
                .filter(candidate -> isOneLetterDifferent(word, candidate))
                .toList();
    }

    private boolean isOneLetterDifferent(String word1, String word2) {
        if (word1.length() != word2.length()) return false;

        int diffCount = 0;
        for (int i = 0; i < word1.length(); i++) {
            if (word1.charAt(i) != word2.charAt(i)) diffCount++;
            if (diffCount > 1) return false;
        }
        return diffCount == 1;
    }

    private List<Map<String, Object>> loadWordUsages(Object wordId, MongoCollection<Document> usageCollection) {
        List<Map<String, Object>> usages = new ArrayList<>();

        try {
            for (Document usage : usageCollection.find(new Document("word_id", wordId))) {
                Map<String, Object> usageData = new HashMap<>();
                usageData.put("book", usage.getString("book"));
                usageData.put("author", usage.getString("author"));
                usageData.put("frequency", usage.getInteger("frequency", 0));
                usages.add(usageData);
            }
        } catch (Exception e) {
            System.err.println("Error while loading usages for word_id '" + wordId + "': " + e.getMessage());
            e.printStackTrace();
        }

        return usages;
    }
}
