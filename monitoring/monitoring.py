def main():
    print("System Monitoring Setup")

    hostname = input("Enter hostname: ")
    ip_address = input("Enter IP address: ")

    metrics = []

    print("\nEnter metrics to monitor (type 'done' to finish):")

    while True:
        metric = input("Metric: ").strip()

        if metric.lower() == "done":
            break

        if metric:
            metrics.append(metric)

    print("\n------ Monitoring Configuration ------")
    print(f"Hostname: {hostname}")
    print(f"IP Address: {ip_address}")

    print("\nMetrics to monitor:")
    if metrics:
        for metric in metrics:
            print(f"- {metric}")
    else:
        print("No metrics entered.")

    print("--------------------------------------")


if __name__ == "__main__":
    main()


