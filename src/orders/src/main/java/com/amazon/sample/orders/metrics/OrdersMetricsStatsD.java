/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

package com.amazon.sample.orders.metrics;

import com.amazon.sample.events.orders.OrderCreatedEvent;
import com.amazon.sample.orders.entities.OrderItemEntity;
import com.timgroup.statsd.NonBlockingStatsDClientBuilder;
import com.timgroup.statsd.StatsDClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;
import lombok.extern.slf4j.Slf4j;

@Component
@Slf4j
public class OrdersMetricsStatsD {
    private final StatsDClient statsd;

    public OrdersMetricsStatsD(
            @Value("${datadog.statsd.host:localhost}") String host,
            @Value("${datadog.statsd.port:8125}") int port,
            @Value("${spring.application.name:orders-service}") String prefix) {
        
        log.info("Initializing StatsD client with host: {}, port: {}, prefix: {}", host, port, prefix);
        
        this.statsd = new NonBlockingStatsDClientBuilder()
            .prefix(prefix)
            .hostname(host)
            .port(port)
            .build();
    }

    @TransactionalEventListener
    public void onOrderCreated(OrderCreatedEvent event) {
        statsd.incrementCounter("statsd.watch.orders", new String[]{"productId:*"});
        
        for (OrderItemEntity orderentity : event.getOrder().getOrderItems()) {
            String[] tags = new String[] {
                "productId:" + orderentity.getProductId()
            };
            statsd.count("statsd.watch.orders", orderentity.getQuantity(), tags);
        }

        int totalPrice = event.getOrder().getOrderItems().stream()
            .mapToInt(OrderItemEntity::getTotalCost)
            .sum();
        statsd.gauge("statsd.watch.orderTotal", totalPrice);
    }
}
