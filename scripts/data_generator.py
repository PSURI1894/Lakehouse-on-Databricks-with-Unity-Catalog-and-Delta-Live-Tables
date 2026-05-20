import csv
import json
import os
import random
import time
from datetime import datetime, timedelta
from typing import Dict, List


class SyntheticDataGenerator:
    """Generates highly realistic e-commerce data streams to feed Auto Loader landing zones."""

    def __init__(self, output_root: str) -> None:
        self.output_root = output_root
        self.orders_path = os.path.join(output_root, "orders")
        self.customers_path = os.path.join(output_root, "customers")
        os.makedirs(self.orders_path, exist_ok=True)
        os.makedirs(self.customers_path, exist_ok=True)

        self.countries = ["US", "CA", "GB", "DE", "FR", "JP", "IN", "BR", "invalid_long_code"]
        self.statuses = ["PENDING", "COMPLETED", "SHIPPED", "CANCELLED", "REFUNDED"]

    def generate_customers_batch(self, count: int = 100) -> str:
        """Generates customer updates in CSV format, incorporating schema drift and faulty emails."""
        timestamp = datetime.utcnow()
        filename = f"customers_{int(time.time())}.csv"
        filepath = os.path.join(self.customers_path, filename)

        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["customer_id", "first_name", "last_name", "email", "updated_at"])

            for idx in range(count):
                cust_id = f"CUST_{random.randint(10000, 99999)}"
                f_name = random.choice(["Alex", "Sarah", "John", "Emily", "Michael", "Sophia"])
                l_name = random.choice(["Smith", "Jones", "Taylor", "Brown", "Wilson", "Miller"])
                
                # Inject random email defects to test DLT drop/fail rules
                if random.random() < 0.05:
                    email = f"faulty_email_address_{idx}"  # missing @
                else:
                    email = f"{f_name.lower()}.{l_name.lower()}@enterprise.com"

                updated_at = (timestamp - timedelta(minutes=random.randint(0, 1440))).isoformat()
                writer.writerow([cust_id, f_name, l_name, email, updated_at])

        print(f"Generated CSV customers batch: {filepath}")
        return filepath

    def generate_orders_batch(self, count: int = 500) -> str:
        """Generates transactional order logs in JSON lines format, including nulls and negative amounts."""
        timestamp = datetime.utcnow()
        filename = f"orders_{int(time.time())}.json"
        filepath = os.path.join(self.orders_path, filename)

        with open(filepath, "w", encoding="utf-8") as f:
            for _ in range(count):
                # Inject null primary keys to test DLT FAIL rules
                order_id = None if random.random() < 0.02 else f"ORD_{random.randint(100000, 999999)}"
                cust_id = f"CUST_{random.randint(10000, 99999)}"
                prod_id = f"PROD_{random.randint(100, 999)}"
                
                # Inject negative amount to test DLT DROP rules
                amount = round(random.uniform(-50.0, 1500.0), 2) if random.random() < 0.03 else round(random.uniform(5.0, 2500.0), 2)
                country = random.choice(self.countries)
                status = random.choice(self.statuses)
                updated_at = (timestamp - timedelta(minutes=random.randint(0, 1440))).isoformat()

                record = {
                    "order_id": order_id,
                    "customer_id": cust_id,
                    "product_id": prod_id,
                    "amount": amount,
                    "country_code": country,
                    "order_status": status,
                    "updated_at": updated_at
                }
                
                # Inject random schema drift column
                if random.random() < 0.10:
                    record["referrer_campaign"] = random.choice(["black_friday", "summer_sale", "newsletter"])

                f.write(json.dumps(record) + "\n")

        print(f"Generated JSON orders batch: {filepath}")
        return filepath


if __name__ == "__main__":
    # Simulate generating data into a temporary workspace landing folder
    workspace_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    mock_landing = os.path.join(workspace_root, "landing")
    
    generator = SyntheticDataGenerator(mock_landing)
    generator.generate_customers_batch(count=150)
    generator.generate_orders_batch(count=1000)
