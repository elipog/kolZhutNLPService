package com.salesforce.research.poc;

import org.glassfish.hk2.utilities.binding.AbstractBinder;

public class HK2ModuleBinder extends AbstractBinder {
    @Override
    protected void configure() {
        //System.out.println("Binder");
        //bind(OpenIETripletParser.class).to(TripletParser.class).in(Singleton.class);
    }
}
