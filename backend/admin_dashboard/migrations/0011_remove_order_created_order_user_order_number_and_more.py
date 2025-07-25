# Generated by Django 5.1.3 on 2025-05-01 16:40

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('admin_dashboard', '0010_make_icon_nullable'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='order',
            name='created',
        ),
        migrations.AddField(
            model_name='order',
            name='user_order_number',
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='order',
            name='delivery_info',
            field=models.JSONField(default=dict),
        ),
    ]
