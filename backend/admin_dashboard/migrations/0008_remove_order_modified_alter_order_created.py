# Generated by Django 5.1.3 on 2025-04-30 19:27

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('admin_dashboard', '0007_order_created_order_modified'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='order',
            name='modified',
        ),
        migrations.AlterField(
            model_name='order',
            name='created',
            field=models.DateTimeField(auto_now_add=True),
        ),
    ]
