package com.example.datamart;

import com.hazelcast.client.HazelcastClient;
import com.hazelcast.client.config.ClientConfig;
import com.hazelcast.client.config.ClientNetworkConfig;
import com.hazelcast.core.HazelcastInstance;
import com.hazelcast.map.IMap;

public class HazelcastConnection {
    private HazelcastInstance hazelcastClient;

    public HazelcastConnection() {
        ClientConfig clientConfig = new ClientConfig();
        ClientNetworkConfig networkConfig = clientConfig.getNetworkConfig();

        networkConfig.addAddress("127.0.0.1:5701");

        networkConfig.setConnectionTimeout(10000); 

        this.hazelcastClient = HazelcastClient.newHazelcastClient(clientConfig);
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
        }
    }
}
