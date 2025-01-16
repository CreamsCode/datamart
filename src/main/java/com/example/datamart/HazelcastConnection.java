package com.example.datamart;

import com.hazelcast.client.HazelcastClient;
import com.hazelcast.client.config.ClientConfig;
import com.hazelcast.core.HazelcastInstance;
import com.hazelcast.map.IMap;

public class HazelcastConnection {
    private HazelcastInstance hazelcastClient;

    public HazelcastConnection(String hazelcastIp) {
        if (hazelcastIp == null || hazelcastIp.isEmpty()) {
            throw new IllegalArgumentException("Hazelcast IP address must not be null or empty");
        }

        ClientConfig clientConfig = new ClientConfig();
        clientConfig.getNetworkConfig()
                    .addAddress(hazelcastIp + ":5701");

        this.hazelcastClient = HazelcastClient.newHazelcastClient(clientConfig);
        System.out.println("Connected to Hazelcast at " + hazelcastIp + ":5701");
    }

    public HazelcastInstance getHazelcastClient() {
        return hazelcastClient;
    }

    public IMap<String, String> getWordsMap() {
        return hazelcastClient.getMap("words_map");
    }

    public IMap<String, String> getGraphMap() {
        return hazelcastClient.getMap("graph_map");
    }

    public void close() {
        if (hazelcastClient != null) {
            hazelcastClient.shutdown();
            System.out.println("Hazelcast client connection closed.");
        }
    }
}
