package com.example.datamart;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoDatabase;
import com.mongodb.client.MongoCollection;
import org.bson.Document;

public class MongoDBConnection {

    private final String uri;
    private final String dbName;
    private MongoClient client;
    private MongoDatabase database;

    public MongoDBConnection(String uri, String dbName) {
        this.uri = uri;
        this.dbName = dbName;
    }

    public void connect() {
        try {
            client = MongoClients.create(uri);
            database = client.getDatabase(dbName);
            System.out.println("Connected to MongoDB at " + uri);
        } catch (Exception e) {
            System.err.println("Error connecting to MongoDB: " + e.getMessage());
            throw e;
        }
    }

    public MongoCollection<Document> getCollection(String collectionName) {
        if (database == null) {
            throw new IllegalStateException("Database connection is not initialized. Call connect() first.");
        }
        return database.getCollection(collectionName);
    }

    public void close() {
        if (client != null) {
            client.close();
            System.out.println("MongoDB connection closed.");
        }
    }
}

