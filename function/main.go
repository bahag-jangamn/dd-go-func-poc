package go_func_dd_poc

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/sirupsen/logrus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

var (
	tracer         = otel.Tracer("dd-go-func-poc")
	meter          = otel.Meter("dd-go-func-poc")
	requestCounter metric.Int64Counter

	priceGauge metric.Float64Gauge
	stockGauge metric.Int64Gauge
)

func init() {
	setupOTel()

	var err error
	requestCounter, err = meter.Int64Counter("mp.offers.total")
	if err != nil {
		logrus.Fatal(err)
	}

	priceGauge, err = meter.Float64Gauge("mp.offer.price")
	if err != nil {
		logrus.Fatal(err)
	}

	stockGauge, err = meter.Int64Gauge("mp.offer.stock")
	if err != nil {
		logrus.Fatal(err)
	}

	functions.HTTP("HelloWorld", HelloWorld)
}

func HelloWorld(w http.ResponseWriter, r *http.Request) {
	currentPrice := 0.0
	currentStock := int64(0)
	currentOfferID := ""
	ctx, span := tracer.Start(r.Context(), "HandleRequest")
	defer span.End()

	currentOfferID = r.URL.Query().Get("offerId") // e.g. ?offerId=123
	operation := r.URL.Query().Get("op")          // e.g. &op=upsert
	if priceStr := r.URL.Query().Get("price"); priceStr != "" {
		if p, err := strconv.ParseFloat(priceStr, 64); err == nil {
			currentPrice = p
		} else {
			currentPrice = 100.0
		}
	}
	if stockStr := r.URL.Query().Get("stock"); stockStr != "" {
		if s, err := strconv.ParseInt(stockStr, 10, 64); err == nil {
			currentStock = s
		} else {
			currentStock = 50
		}
	}

	status := "success"
	if currentOfferID != "" {
		if idNum, err := strconv.Atoi(currentOfferID); err == nil && idNum%2 != 0 {
			status = "failure"
		}
	}
	// ----------------------------------

	logrus.WithContext(ctx).Infof("Processing %s for offer %s", operation, currentOfferID)

	_, childSpan := tracer.Start(ctx, "ExpensiveOperation")
	time.Sleep(100 * time.Millisecond)
	childSpan.End()

	requestCounter.Add(ctx, 1, metric.WithAttributes(
		attribute.String("status", status),
		attribute.String("operation", operation),
		attribute.String("path", r.URL.Path),
	))

	stockGauge.Record(ctx, currentStock, metric.WithAttributes(attribute.String("offerId", currentOfferID)))
	priceGauge.Record(ctx, currentPrice, metric.WithAttributes(attribute.String("offerId", currentOfferID)))

	if mp, ok := otel.GetMeterProvider().(*sdkmetric.MeterProvider); ok {
		if err := mp.ForceFlush(context.Background()); err != nil {
			logrus.Errorf("Error flushing metrics: %v", err)
		}
	}
	if tp, ok := otel.GetTracerProvider().(*sdktrace.TracerProvider); ok {
		if err := tp.ForceFlush(context.Background()); err != nil {
			logrus.Errorf("Error flushing traces: %v", err)
		}
	}

	fmt.Fprintf(w, "Telemetry sent for Offer: %s", currentOfferID)
}

func setupOTel() {
	ctx := context.Background()
	res, _ := resource.Merge(resource.Default(), resource.NewWithAttributes(
		semconv.SchemaURL,
		semconv.ServiceNameKey.String("dd-go-func-poc"),
	))

	traceExp, _ := otlptracehttp.New(ctx, otlptracehttp.WithEndpoint("localhost:4318"), otlptracehttp.WithInsecure())
	tp := sdktrace.NewTracerProvider(sdktrace.WithBatcher(traceExp), sdktrace.WithResource(res))
	otel.SetTracerProvider(tp)

	metricExp, _ := otlpmetrichttp.New(ctx, otlpmetrichttp.WithEndpoint("localhost:4318"), otlpmetrichttp.WithInsecure(), otlpmetrichttp.WithTemporalitySelector(deltaSelector))
	mp := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExp, sdkmetric.WithInterval(5*time.Second))),
	)
	otel.SetMeterProvider(mp)
}

func deltaSelector(kind sdkmetric.InstrumentKind) metricdata.Temporality {
	switch kind {
	case sdkmetric.InstrumentKindCounter,
		sdkmetric.InstrumentKindObservableCounter,
		sdkmetric.InstrumentKindHistogram:
		return metricdata.DeltaTemporality
	}
	return metricdata.CumulativeTemporality
}
