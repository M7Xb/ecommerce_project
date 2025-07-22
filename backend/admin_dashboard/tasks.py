from django.utils import timezone
from .models import Deal, Product

def update_deal_statuses():
    now = timezone.now()
    print(f"\nUpdating deal statuses at {now}")
    
    # Update expired deals
    expired_deals = Deal.objects.filter(
        is_active=True,
        end_date__lte=now
    )
    print(f"Found {expired_deals.count()} expired deals")
    for deal in expired_deals:
        print(f"Deactivating expired deal for {deal.product.title}")
        print(f"End date: {deal.end_date}")
        deal.is_active = False
        deal.save()
        
        # Reset product sale status
        product = deal.product
        product.is_on_sale = False
        product.sale_price = None
        product.save()

    # Update started deals
    active_deals = Deal.objects.filter(
        is_active=True,
        start_date__lte=now,
        end_date__gt=now
    )
    print(f"Found {active_deals.count()} active deals")
    for deal in active_deals:
        print(f"Updating active deal for {deal.product.title}")
        product = deal.product
        product.is_on_sale = True
        product.sale_price = deal.discount_price
        product.save()
