import datamart.DataMart;
import datamart.HazelcastConnection;
import datamart.MongoDBConnection;

public class Main {
    public static void main(String[] args) {
        String mongoIp = System.getenv("MONGO_IP");
        String mongoUri = "mongodb://" + mongoIp + ":27017/";
        String dbName = "graph_words_db";
        String hazelcastIp = System.getenv("HAZELCAST_IP");

        if (hazelcastIp == null || hazelcastIp.isEmpty()) {
            System.err.println("Error: HAZELCAST_IP environment variable is not set.");
            return;
        }

        HazelcastConnection hazelcastConnection = new HazelcastConnection(hazelcastIp);

        if (mongoIp == null || mongoIp.isEmpty()) {
            System.err.println("Error: MONGO_URI environment variable is not set.");
            return;
        }

        MongoDBConnection mongoConnection = new MongoDBConnection(mongoUri, dbName);

        try {
            mongoConnection.connect();

            DataMart dataMart = new DataMart(mongoConnection, hazelcastConnection);

            long startTime = System.currentTimeMillis();
            dataMart.buildDataMart();
            long endTime = System.currentTimeMillis();

            long duration = endTime - startTime;
            System.out.println("Time taken to build DataMart: " + (duration / 1000.0) + " seconds");

        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            mongoConnection.close();
            hazelcastConnection.close();
        }
    }
}
