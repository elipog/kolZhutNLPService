package com.salesforce.research.poc;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.jaxrs.json.JacksonJaxbJsonProvider;
import org.glassfish.hk2.api.ServiceLocator;
import org.glassfish.jersey.server.ResourceConfig;

import javax.inject.Inject;


public class MyApplication extends ResourceConfig{

    @Inject
    public MyApplication(ServiceLocator serviceLocator){
        System.out.println("Application");
        // create custom ObjectMapper
        ObjectMapper mapper = new ObjectMapper();
        mapper.enable(SerializationFeature.INDENT_OUTPUT);

        // create JsonProvider to provide custom ObjectMapper
        JacksonJaxbJsonProvider provider = new JacksonJaxbJsonProvider();
        provider.setMapper(mapper);

        register(provider);

        register(new HK2ModuleBinder());

        packages("com.salesforce.research.poc.webservice");

    }
}
